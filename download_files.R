Rfuns::load_pkgs('data.table', 'dplyr', 'geojsonsf', 'qs', 'rvest')

zip_path <- file.path(ext_path, 'wd', 'bing_roads')
out_path <- file.path(data_path, 'wd', 'bing_roads')

# download zip files -----------------------
# y <- read_html('https://github.com/microsoft/RoadDetections/') |> 
#         html_elements('td:nth-child(2) a') |> 
#         html_attr('href')
# for(idx in 1:length(y)) download.file(y[idx], zip_path)

# read and convert countries but USA -------
yc <- fread('./countries.csv')
yc[, `:=`( nlines = 0, nfiles =  0 )]
setDTthreads(parallel::detectCores() - 2)
for(fn in list.files(zip_path)){
    if(fn != 'USA.zip'){
        message('Processing ', gsub('(.*)-.*', '\\1', fn))
        y <- fread(cmd = paste0('unzip -cq ', zip_path, '/', fn), header = FALSE, col.names = c('iso3', 'geometry'))
        for(x in unique(y$iso3)){
            message(' - ', x)
            yt <- geojson_sf(y[iso3 ==  x, geometry]) |> st_make_valid() 
            yc[iso3 == x, nlines := nrow(yt)]
            qsave(yt, file.path(out_path, x), nthreads = 8)
        }
    }
}

# USA ---------------------------------------
## read and convert USA boundaries ----
tmpf <- tempfile()
tmpd <- tempdir()
unzip(file.path(zip_path, 'USA.zip'), exdir = tmpd)
y <- vroom::vroom(file.path(tmpd, list.files(tmpd, 'tsv')), delim = '\t', col_names = 'geometry')
y <- y$geometry |> geojson_sf()
y <- y |>  mutate(n = mapview::npts(y, by_feature = TRUE)) |> 
        filter(n > 1) |>                                       # from 54484737 to 54279948
        st_make_valid()
y <- y |> mutate(n = mapview::npts(y, by_feature = TRUE)) |> 
        filter(n > 1) |>                                       # from 54279948 to 54035251
        select(-n) |> 
        st_transform(4269) |>                                  # EPSG:4269 - NAD83 
        mutate(id = row_number())
# qsave(y, file.path(out_path, 'USA'), nthreads = 8)
# y <- qread(file.path(out_path, 'USA'), nthreads = 8)

## download USA states boundaries -----
download.file('https://www2.census.gov/geo/tiger/GENZ2018/shp/cb_2018_us_state_500k.zip', tmpf)
unzip(tmpf, exdir = tmpd)
yb <- st_read(file.path(tmpd, grep('.*shp$', unzip(tmpf, list = TRUE)$Name, value = TRUE))) |> 
        st_transform(st_crs(y)) |> 
        subset(select = c(GEOID, STUSPS, NAME)) |> 
        setNames(c('id', 'code', 'name', 'geometry')) |> 
        arrange(id) |> 
        filter(code %in% ys$code)
unlink(c(tmpf, tmpd))

## separate by USA states -------------
ys <- fread('./states.csv')
ys[, `:=`(nlines = 0, nfiles = 1)]
for(st in ys$code){
    message('Processing ', st)
    yt <- y |> st_filter(yb |> filter(code == st))
    y <- y |> filter(!id %in% yt$id)
    ys[code == st, nlines := nrow(yt)]
    qsave(yt |> st_transform(4326), file.path(out_path, st), nthreads = 8)
    rm(yt); gc()
}
## recuperate missing (95,225) --------
y <- y |> mutate(yb[st_nearest_feature(y, yb), 'code'] |> st_drop_geometry()) |> st_transform(4326)
for(st in ys$code){
    message('Processing ', st)
    yt <- qread(file.path(out_path, st), nthreads = 8)
    yt <- rbind(yt, y |> filter(code == st) |> select(id)) |> st_geometry() |> st_as_sf() |> st_set_geometry('geometry')
    ys[code == st, nlines := nrow(yt)]
    qsave(yt, file.path(out_path, st), nthreads = 8)
    rm(yt); gc()
}
yc[iso3 == 'USA', nlines := sum(ys$nlines)]
yc[nlines > 0, nfiles := 1]

# Saving `sf` boundaries -------------------
## less than 100MB --------------------
yf <- data.table(gsub('.* ([0-9]{4,9}) .* (.{2,3}$)', '\\2 \\1', system(paste('ls -l', out_path), intern = TRUE)))[, tstrsplit(V1, ' ')][V1 != 'total'][, V2 := as.integer(V2)][order(V1)]
for(x in yf[V2 < 1e8, V1]){
    message('Saving ', x)
    qsave(qread(file.path(out_path, x), nthreads = 8), paste0('./', x), nthreads = 8)
}
## over 100Mb in chunks <100MB ---------
yf <- yf[V2 >= 1e8]
for(idx in 1:nrow(yf)){
    x <- yf[idx]
    message('Processing ', x$V1)
    y <- qread(file.path(out_path, x$V1), nthreads = 8)
    yn <- ceiling(as.numeric(x$V2) / 1e8)
    message(' - splitting in ', yn, ' files')
    yr <- seq(1, nrow(y), len = yn + 1)
    if(nchar(x$V1) == 3) { yc[iso3 == x$V1, nfiles := yn] } else { ys[code == x$V1, nfiles := yn] }
    for(xx in 1:yn) qsave(y[yr[xx]:yr[xx + 1],], paste0('./', x$V1, xx), nthreads = 8)
}

# write ancillary datasets -----------------
fwrite(ys, './states.csv')
yc[iso3 == 'USA', `:=`( nlines = sum(ys$nlines), nfiles = sum(ys$nfiles) )]
fwrite(yc, './countries.csv')

# clean environment and cache --------------
rm(list = ls())
gc()

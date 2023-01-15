# Bing Roads as $R$ `sf` digital files

[Bing Maps](https://blogs.bing.com/maps/2022-12/Bing-Maps-is-bringing-new-roads) has released in late 2022, through the [Microsoft GitHub account](https://github.com/microsoft/RoadDetections/), a whole bunch of mined roads around the world, covering in all ~48 millions km over 202 Countries.

I've downloaded all zipped GeoJSON files, partitioned by Country (see the 3-chars `iso3` column in the `countries.csv` file) and US State (see the 2-chars `code` column in the `states.csv` file), and converted each as digital vector files to be easily loaded into $R$ using the [sf](https://cran.r-project.org/package=sf) package. The coordinate reference system is [WGS84](https://epsg.io/4326) or `EPSG:4326`.

You can find all the files at [this location](https://1drv.ms/f/s!AjLylE7EHUYSif5_eYKEVl3OJ1RdNg), for 202 Countries and 49 US States (the number of *lines* in each country/state file can be found in the column `nlines` in the two `csv` files mentioned above). 

The files have been serialized using the [qs](https://cran.r-project.org/package=qs) package.

I suggest you use the [leaflet](https://cran.r-project.org/package=leaflet) package to visualize the roads, together with the [leafgl](https://cran.r-project.org/package=leafgl) add-on:
```
library(qs)
library(sf)
library(leaflet)
library(leafgl)
y <- qread('/path/to/downloads/XXX')
leaflet() |> addTiles() |> addGlPolylines(y)
```

The biggest file is for *India*, with more than 13 millions lines, needing at least 7GB RAM only to keep the spatial data in memory. Acting on it requires obviously more memory for operations. For example, filtering out the roads for the Capital city only, ~120K, requires more than 16GB:
```
y <- qread('/path/to/downloads/IND')
yx <- st_read('/path/to/delhi_administrative.shp')
ynd <- y |> filter(yx)
leaflet() |> 
    addTiles() |>
    addPolylines(data = yx |> st_cast('LINESTRING'), color = 'black', fillOpacity = 0) |> 
    addGlPolylines(ynd)
```
You can see the result with the attached leaflet html map `New_Delhi.html`

Finally, notice that ~450K US roads (out of more than 54 mlns) have been deleted because of either being single points or dropped in the validation process. This problem was not reported in any of the other Country's files.

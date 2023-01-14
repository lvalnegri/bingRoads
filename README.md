# Bing Roads as $R$ `sf` digital files

[Bing Maps](https://blogs.bing.com/maps/2022-12/Bing-Maps-is-bringing-new-roads) has released in late 2022, through the [Microsoft GitHub account](https://github.com/microsoft/RoadDetections/), a whole bunch of mined roads around the world, covering in all ~48 millions km over 202 Countries.

I've downloaded all zipped GeoJSON files, partitioned by Country (see the 3-chars `iso3` column in the `countries.csv` file) and US State (see the 2-chars `code` column in the `states.csv` file), and converted each as digital vector files to be easily loaded into $R$ using the [sf](https://cran.r-project.org/package=sf) package. The Reference System is [WGS84](https://epsg.io/4326).

You can find all files [here](https://1drv.ms/f/s!AjLylE7EHUYSif5_eYKEVl3OJ1RdNg), for 202 Countries and 49 US States (the number of roads in each country/state can be found in the column `nlines` in the two `csv` files.

Notice that ~450K US roads (out of more than 54 mlns) have been deleted because of either being single points or dropped in the validation process. This problem was not reported in any of the other Country's files.
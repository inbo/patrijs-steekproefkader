library(osmdata)
library(tidyverse)
library(sf)

options(timeout = max(1000, getOption("timeout")))
vlaanderen_bbox <- structure(
  c(
    xmin = 2.54132805273813, ymin = 50.6874925131215,
    xmax = 5.91110964318081, ymax = 51.5051136582605
  ),
  class = "bbox",
  crs = structure(
    list(
      input = "EPSG:4326",
      wkt = "GEOGCRS[\"WGS 84\",
    DATUM[\"World Geodetic System 1984\",
        ELLIPSOID[\"WGS 84\",6378137,298.257223563,
            LENGTHUNIT[\"metre\",1]]],
    PRIMEM[\"Greenwich\",0,
        ANGLEUNIT[\"degree\",0.0174532925199433]],
    CS[ellipsoidal,2],
        AXIS[\"geodetic latitude (Lat)\",north,
            ORDER[1],
            ANGLEUNIT[\"degree\",0.0174532925199433]],
        AXIS[\"geodetic longitude (Lon)\",east,
            ORDER[2],
            ANGLEUNIT[\"degree\",0.0174532925199433]],
    USAGE[
        SCOPE[\"unknown\"],
        AREA[\"World\"],
        BBOX[-90,-180,90,180]],
    ID[\"EPSG\",4326]]"
    ),
    class = "crs"
  )
)
overpass_url <- "https://lz4.overpass-api.de/api/interpreter"
set_overpass_url(overpass_url[1])
qq <- opq(bbox = unname(vlaanderen_bbox), timeout = getOption("timeout"))
qq %>%
  add_osm_feature(key = "railway", value = "rail") %>%
  osmdata_sf() %>%
  `[[`("osm_lines") %>%
  st_transform(crs = 31370) %>%
  st_buffer(10) %>%
  select(.data$osm_id) %>%
  st_union() %>%
  st_write("spoorweg.shp")

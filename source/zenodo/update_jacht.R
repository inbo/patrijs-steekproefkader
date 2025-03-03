renv::restore()
library(curl)
library(here)
library(keyring)
library(tidyverse)
library(sf)
library(zen4R)

target <- here("data", "downloads")

query <- c(
  request = "GetFeature", typeName = "Jacht:Jachtterr",
  outputFormat = "json", srsName = "epsg:31370",
  BBOX = "23000,150000,140000,250000"
)
paste(names(query), query, sep = "=", collapse = "&") |>
  sprintf(fmt = "https://geo.api.vlaanderen.be/Jacht/wfs?%s") |>
  curl_download(here(target, "jacht_west.json"))
here(target, "jacht_west.json") |>
  read_sf() -> jacht_west
stopifnot(nrow(jacht_west) < 10000)

query <- c(
  request = "GetFeature", typeName = "Jacht:Jachtterr",
  outputFormat = "json", srsName = "epsg:31370",
  BBOX = "140000,150000,260000,250000"
)
paste(names(query), query, sep = "=", collapse = "&") |>
  sprintf(fmt = "https://geo.api.vlaanderen.be/Jacht/wfs?%s") |>
  curl_download(here(target, "jacht_oost.json"))
here(target, "jacht_oost.json") |>
  read_sf() -> jacht_oost
stopifnot(nrow(jacht_oost) < 10000)

jacht_oost[!jacht_oost$UIDN %in% jacht_west$UIDN, ] |>
  bind_rows(jacht_west) |>
  st_transform(crs = 3857) -> jacht
st_write(jacht, here(target, "jacht.gpkg"), append = FALSE)
st_write(jacht, here(target, "jacht.shp"), append = FALSE)
file.remove(here(target, "jacht_west.json"))
file.remove(here(target, "jacht_oost.json"))

timestamp <- file.info(here(target, "jacht.shp"))$ctime
zenodo <- ZenodoManager$new(token = key_get("zenodo"), logger = "INFO")
myrec <- zenodo$getDepositionByDOI("10.5281/zenodo.5584204")
myrec <- zenodo$depositRecordVersion(
  myrec, delete_latest_files = TRUE, publish = FALSE,
  here(target) |>
    list.files(pattern = "jacht\\.(gpkg|dbf|shp|shx|prj)$", full.names = TRUE)
)
myrec$setPublicationDate(as.Date(timestamp))
format(timestamp, "%Y-%m-%d %H:%M:%S") |>
  sprintf(fmt = "WFS download %s") |>
  myrec$setVersion()
myrec <- zenodo$depositRecord(myrec, publish = TRUE)

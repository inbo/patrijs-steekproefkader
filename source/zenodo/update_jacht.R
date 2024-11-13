renv::restore()
library(here)
library(keyring)
library(curl)
library(tidyverse)
library(zen4R)

target <- here("data", "downloads")
query = c(
  request = "GetFeature", typeName = "Jacht:Jachtterr",
  outputFormat = "SHAPE-ZIP", srsName = "epsg:3857"
)
paste(names(query), query, sep = "=", collapse = "&") |>
  sprintf(fmt = "https://geo.api.vlaanderen.be/Jacht/wfs?%s") |>
  curl_download(here(target, "jacht.zip"))
unzip(here(target, "jacht.zip"), exdir = target)
timestamp <- file.info(here(target, "Jachtterr.shp"))$ctime

zenodo <- ZenodoManager$new(token = key_get("zenodo"), logger = "INFO")
myrec <- zenodo$getDepositionByDOI("10.5281/zenodo.5584204")
myrec <- zenodo$depositRecordVersion(
  myrec, delete_latest_files = TRUE, here(target, "jacht.zip")
)
myrec$setPublicationDate(as.Date(timestamp))
format(timestamp, "%Y-%m-%d %H:%M:%S") |>
  sprintf(fmt = "WFS download %s") |>
  myrec$setVersion()
myrec <- zenodo$depositRecord(myrec, publish = TRUE)

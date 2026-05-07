renv::restore()
library(keyring)
library(zen4R)
library(osmextract)
library(git2rdata)
library(tidyverse)

osm_source <- oe_match("Belgium")
osm_pbf <- oe_download(
  file_url = osm_source$url,
  file_size = osm_source$file_size
)

zenodo <- ZenodoManager$new(token = key_get("zenodo"), logger = "INFO")
myrec <- zenodo$getDepositionByDOI("10.5281/zenodo.5792949")
myrec <- zenodo$depositRecordVersion(
  myrec,
  delete_latest_files = TRUE,
  files = osm_pbf,
  publish = FALSE
)
myrec$setPublicationDate(Sys.Date())
myrec$setVersion(Sys.Date())
myrec <- zenodo$depositRecord(myrec, publish = TRUE)

read_vc("checksum", dl) |>
  filter(file != "geofabrik_belgium-latest.osm.pbf") |>
  bind_rows(
    data.frame(
      file = "geofabrik_belgium-latest.osm.pbf",
      sha512 = file(osm_pbf) |>
        sha512() |>
        as.character() |>
        unclass()
    )
  ) |>
  write_vc("checksum", root = dl, optimize = FALSE)

renv::restore()
library(keyring)
library(zen4R)
library(osmextract)

osm_source <- oe_match("Belgium")
osm_pbf <- oe_download(
  file_url = osm_source$url, file_size = osm_source$file_size
)

zenodo <- ZenodoManager$new(token = key_get("zenodo"), logger = "INFO")
myrec <- zenodo$getDepositionById("5792949")
myrec <- zenodo$depositRecordVersion(
  myrec, delete_latest_files = TRUE, files = osm_pbf, publish = FALSE
)
myrec$setPublicationDate(Sys.Date())
myrec$setVersion(Sys.Date())
myrec <- zenodo$depositRecord(myrec, publish = TRUE)

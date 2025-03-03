renv::restore()
library(here)
library(keyring)
library(zen4R)
library(tidyverse)
source_folder <- here("data", "fieldmap", "osm")
zenodo <- ZenodoManager$new(token = key_get("zenodo"), logger = "INFO")

new_version <- "2025.05"
doi <- c(
  wevl = "10.5281/zenodo.14647585", oovl = "10.5281/zenodo.14194002",
  antw = "10.5281/zenodo.14194017", limb = "10.5281/zenodo.14194025",
  vlbr = "10.5281/zenodo.14194042"
)

for (current in names(doi)) {
  myrec <- zenodo$getDepositionByDOI(doi[current])
  myrec <- zenodo$depositRecordVersion(
    record = myrec, delete_latest_files = TRUE, publish = FALSE
  )
  myrec$setPublicationDate(Sys.Date())
  myrec$setVersion(new_version)
  source_folder %>%
    file.path(current) %>%
    list.files(full.names = TRUE) -> to_do
  walk(to_do, zenodo$uploadFile, record = myrec)
  zenodo$getFiles(myrec$id) %>%
    map_chr("key") -> done
  to_do <- to_do[!basename(to_do) %in% done]
  stopifnot(length(to_do) == 0)
  myrec <- zenodo$depositRecord(myrec, publish = TRUE)
}

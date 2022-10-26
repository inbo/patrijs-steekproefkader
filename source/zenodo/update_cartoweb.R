renv::restore()
library(here)
library(keyring)
library(zen4R)
library(tidyverse)
source_folder <- here("data", "fieldmap", "cartoweb")
zenodo <- ZenodoManager$new(token = key_get("zenodo"), logger = "INFO")

new_version <- "2023.01"
doi <- c(
  vlbr = 5827510, limb = 5827492, antw = 5827468, oovl = 5831529,
  wevl = 5827429
)

current <- "vlbr"
myrec <- zenodo$getDepositionById(doi[current])
myrec <- zenodo$depositRecordVersion(
  record = myrec, delete_latest_files = TRUE, publish = FALSE
)
myrec$setPublicationDate(Sys.Date())
myrec$setVersion(new_version)
source_folder %>%
  file.path(current) %>%
  list.files(full.names = TRUE) -> to_do
while (length(to_do) > 0) {
  walk(to_do, zenodo$uploadFile, record = myrec)
  zenodo$getFiles(myrec$id) %>%
    map_chr("filename") -> done
  to_do <- to_do[!basename(to_do) %in% done]
}
myrec <- zenodo$depositRecord(myrec, publish = TRUE)

current <- "limb"
myrec <- zenodo$getDepositionById(doi[current])
myrec <- zenodo$depositRecordVersion(
  record = myrec, delete_latest_files = TRUE, publish = FALSE
)
myrec$setPublicationDate(Sys.Date())
myrec$setVersion(new_version)
source_folder %>%
  file.path(current) %>%
  list.files(full.names = TRUE) -> to_do
while (length(to_do) > 0) {
  walk(to_do, zenodo$uploadFile, record = myrec)
  zenodo$getFiles(myrec$id) %>%
    map_chr("filename") -> done
  to_do <- to_do[!basename(to_do) %in% done]
}
myrec <- zenodo$depositRecord(myrec, publish = TRUE)

current <- "antw"
myrec <- zenodo$getDepositionById(doi[current])
myrec <- zenodo$depositRecordVersion(
  record = myrec, delete_latest_files = TRUE, publish = FALSE
)
myrec$setPublicationDate(Sys.Date())
myrec$setVersion(new_version)
source_folder %>%
  file.path(current) %>%
  list.files(full.names = TRUE) -> to_do
while (length(to_do) > 0) {
  walk(to_do, zenodo$uploadFile, record = myrec)
  zenodo$getFiles(myrec$id) %>%
    map_chr("filename") -> done
  to_do <- to_do[!basename(to_do) %in% done]
}
myrec <- zenodo$depositRecord(myrec, publish = TRUE)

current <- "oovl"
myrec <- zenodo$getDepositionById(doi[current])
myrec <- zenodo$depositRecordVersion(
  record = myrec, delete_latest_files = TRUE, publish = FALSE
)
myrec$setPublicationDate(Sys.Date())
myrec$setVersion(new_version)
source_folder %>%
  file.path(current) %>%
  list.files(full.names = TRUE) -> to_do
while (length(to_do) > 0) {
  walk(to_do, zenodo$uploadFile, record = myrec)
  zenodo$getFiles(myrec$id) %>%
    map_chr("filename") -> done
  to_do <- to_do[!basename(to_do) %in% done]
}
myrec <- zenodo$depositRecord(myrec, publish = TRUE)

current <- "wevl"
myrec <- zenodo$getDepositionById(doi[current])
myrec <- zenodo$depositRecordVersion(
  record = myrec, delete_latest_files = TRUE, publish = FALSE
)
myrec$setPublicationDate(Sys.Date())
myrec$setVersion(new_version)
source_folder %>%
  file.path(current) %>%
  list.files(full.names = TRUE) -> to_do
while (length(to_do) > 0) {
  walk(to_do, zenodo$uploadFile, record = myrec)
  zenodo$getFiles(myrec$id) %>%
    map_chr("filename") -> done
  to_do <- to_do[!basename(to_do) %in% done]
}
myrec <- zenodo$depositRecord(myrec, publish = TRUE)

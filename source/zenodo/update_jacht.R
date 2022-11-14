renv::restore()
library(here)
library(keyring)
library(zen4R)
library(curl)
library(tidyverse)
target <- here("zenodo")
paste(
  "https://downloadagiv.blob.core.windows.net/jacht/jachtterr/2022-2023",
  "Jacht_Shapefile.zip",
  sep = "/"
) %>%
  curl_download(here(target, "jacht.zip"))

zenodo <- ZenodoManager$new(token = key_get("zenodo"), logger = "INFO")
myrec <- zenodo$getDepositionById("5584204")
myrec <- zenodo$depositRecordVersion(
  myrec, delete_latest_files = TRUE, here(target, "jacht.zip")
)
myrec$setPublicationDate(as.Date("2022-08-24"))
myrec$setVersion("seizoen 2022-2023.01")
myrec <- zenodo$depositRecord(myrec, publish = TRUE)

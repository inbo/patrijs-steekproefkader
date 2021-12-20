library(here)
library(keyring)
library(zen4R)
library(curl)
library(tidyverse)
target <- here("zenodo")
paste(
  "https://downloadagiv.blob.core.windows.net/jacht/jachtterr/2021-2022",
  "Jacht_2021-2022-02_GewVLA_Shapefile.zip",
  sep = "/"
) %>%
  curl_download(here(target, "jacht.zip"))

zenodo <- ZenodoManager$new(token = key_get("zenodo"))
myrec <- zenodo$getDepositionByDOI("10.5281/zenodo.5584204")
myrec <- zenodo$depositRecordVersion(
  myrec, delete_latest_files = TRUE, here(target, "jacht.zip"), publish = TRUE
)

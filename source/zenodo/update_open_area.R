renv::restore()
library(here)
library(keyring)
library(sf)
library(zen4R)

here("data", "open_area", "open_ruimte.gpkg") |>
  read_sf() |>
  write_sf(dsn = here("data", "open_area", "open_ruimte.shp"))
here("data", "sampling", "telblok.gpkg") |>
  read_sf() |>
  write_sf(dsn = here("data", "sampling", "telblok.shp"))

zenodo <- ZenodoManager$new(token = key_get("zenodo"), logger = "INFO")
myrec <- zenodo$getDepositionByDOI("10.5281/zenodo.10260759")
here("data", "open_area") |>
  list.files(
    pattern = "^open_ruimte\\.(gpkg|dbf|prj|shp|shx)$", full.names = TRUE
  ) |>
  zenodo$depositRecordVersion(
    record = myrec, delete_latest_files = TRUE, publish = FALSE
  ) -> myrec
myrec$setPublicationDate(Sys.Date())
myrec$setVersion("2025.04")
myrec <- zenodo$depositRecord(myrec, publish = TRUE)

myrec <- zenodo$getDepositionByDOI("10.5281/zenodo.5814901")
here("data", "sampling") |>
  list.files(
    pattern = "^telblok\\.(gpkg|dbf|prj|shp|shx)$", full.names = TRUE
  ) |>
  zenodo$depositRecordVersion(
    record = myrec, delete_latest_files = TRUE, publish = FALSE
  ) -> myrec
myrec$setPublicationDate(Sys.Date())
myrec$setVersion("2025.04")
myrec <- zenodo$depositRecord(myrec, publish = TRUE)

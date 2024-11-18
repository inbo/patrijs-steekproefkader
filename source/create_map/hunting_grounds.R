renv::restore()
library(here)
library(tidyverse)
library(qgisprocess)
qgis_configure()

download_folder <- here("data", "downloads")
target_folder <- here("data", "open_area")
dir.create(target_folder, showWarnings = FALSE)

source(here("source", "create_map", "download.R"))

here(download_folder, "jachtterr.shp") |>
  setNames("INPUT") |>
  qgis_run_algorithm_p(
    algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
    END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
    OUTPUT = qgis_tmp_vector(), SEPARATE_DISJOINT = FALSE
  ) |>
  qgis_run_algorithm_p(
    algorithm = "native:dissolve", FIELD = c("VELDID", "WBENR"),
    OUTPUT = qgis_tmp_vector(), SEPARATE_DISJOINT = FALSE
  ) |>
  qgis_run_algorithm_p(
    algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
  ) |>
  qgis_run_algorithm_p(
    algorithm = "native:reprojectlayer", TARGET_CRS = "EPSG:4326",
    OUTPUT = here(target_folder, "jacht.gpkg")
  )

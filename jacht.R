library(here)
library(tidyverse)
library(qgisprocess)
qgis_configure()

download_folder <- here("downloads")
target_folder <- here("open_ruimte")
dir.create(target_folder, showWarnings = FALSE)

if (
  !file_test("-f", here(download_folder, "geofabrik_belgium-latest.osm.pbf"))
) {
  source(here("download.R"))
}

here(download_folder, "jachtter.shp") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
    END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:dissolve", FIELD = c("VELDID", "WBENR"),
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:reprojectlayer",
    OUTPUT = here(target_folder, "jacht.gpkg"),
    TARGET_CRS = "PROJ4:+proj=longlat +datum=WGS84 +no_defs"
  )) %>%
  do.call(what = qgis_run_algorithm)
qgis_tmp_clean()

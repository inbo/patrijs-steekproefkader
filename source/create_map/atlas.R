renv::restore()
library(here)
library(tidyverse)
library(sf)
library(qgisprocess)
qgis_configure()

target_folder <- here("data", "fieldmap")

coverage <- here("data", "sampling", "telblok.gpkg")
coverage %>%
  read_sf() %>%
  filter(!is.na(.data$WBENR)) %>%
  pull(.data$VELDID) %>%
  unique() %>%
  sort() -> hunting_grounds

for (this_layout in c("Cartoweb", "luchtfoto", "OSM")) {
  here(
    target_folder, tolower(this_layout),
    c("wevl", "oovl", "antw", "limb", "vlbr")
  ) %>%
    walk(dir.create, showWarnings = FALSE, recursive = TRUE)
  here(target_folder, tolower(this_layout)) %>%
    list.files(recursive = TRUE) %>%
    basename() %>%
    str_replace(".*_(.*)_.*", "\\1") -> done
  to_do <- hunting_grounds[!hunting_grounds %in% done]
  for (hunting in to_do) {
    message(this_layout, " ", hunting)
    prov <- switch(
      str_sub(hunting, end = 1), "1" = "wevl", "2" = "oovl", "3" = "antw",
      "4" = "limb", "5" = "vlbr"
    )
    prov <- here(target_folder, tolower(this_layout), prov)
    qgis_run_algorithm(
      algorithm = "native:atlaslayouttopdf", LAYOUT = this_layout,
      FILTER_EXPRESSION = sprintf("\"VELDID\" = '%s'", hunting), .quiet = TRUE,
      SORTBY_EXPRESSION = "id", PROJECT_PATH = here("data", "steekproef.qgz"),
      COVERAGE_LAYER = sprintf("%s|layername=telblok", coverage), DPI = 300,
      OUTPUT = sprintf("%s/jachtveld_%s_%s.pdf", prov, hunting, this_layout),
      SORTBY_REVERSE = FALSE, FORCE_VECTOR = FALSE, GEOREFERENCE = TRUE,
      INCLUDE_METADATA = TRUE, DISABLE_TILED = FALSE, SIMPLIFY = TRUE,
      TEXT_FORMAT = "Always Export Text as Paths (Recommended)", LAYERS = NULL
    )
  }
}

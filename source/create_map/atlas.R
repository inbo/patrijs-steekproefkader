renv::restore()
library(here)
library(tidyverse)
library(sf)
library(qgisprocess)
qgis_configure()

target_folder <- here("data", "fieldmap")

coverage <- here("data", "sampling", "telblok.gpkg")
coverage |>
  read_sf() |>
  filter(!is.na(.data$WBENR)) |>
  st_drop_geometry() |>
  transmute(
    prov = str_sub(.data$WBENR, end = 1) |>
      factor(
        levels = c("1", "2", "3", "4", "5"),
        labels = c("wevl", "oovl", "antw", "limb", "vlbr")
      ),
    wbe = .data$WBENR, hunting = .data$VELDID
  ) |>
  distinct() |>
  arrange(.data$prov, .data$wbe, .data$hunting) -> hunting_grounds

render_wbe <- function(this_layout = "luchtfoto", this_wbe, target_folder) {
  here(
    target_folder, tolower(this_layout), head(this_wbe$prov, 1)
  ) |>
    normalizePath() -> prov
  dir.create(prov, showWarnings = FALSE, recursive = TRUE)
  list.files(prov, pattern = ".*.pdf") |>
    gsub(pattern = "jachtveld_(.*)_.*", replacement = "\\1") -> done
  this_wbe <- this_wbe[!this_wbe$hunting %in% done, ]
  for (hunting in this_wbe$hunting) {
    message(this_layout, " ", hunting)
    qgis_run_algorithm(
      algorithm = "native:atlaslayouttopdf", LAYOUT = this_layout,
      FILTER_EXPRESSION = sprintf("\"VELDID\" = '%s'", hunting), .quiet = TRUE,
      SORTBY_EXPRESSION = "id", PROJECT_PATH = here("data", "steekproef.qgz"),
      COVERAGE_LAYER = sprintf("%s|layername=telblok", coverage), DPI = 300,
      OUTPUT = sprintf("%s/jachtveld_%s_%s.pdf", prov, hunting, this_layout),
      SORTBY_REVERSE = FALSE, FORCE_VECTOR = FALSE, GEOREFERENCE = TRUE,
      INCLUDE_METADATA = TRUE, DISABLE_TILED = FALSE, SIMPLIFY = TRUE,
      TEXT_FORMAT = "Always Export Text as Paths (Recommended)", LAYERS = NULL,
      FORCE_RASTER = FALSE, IMAGE_COMPRESSION = "Lossy (JPEG)"
    )
  }
  oldwd <- getwd()
  on.exit(setwd(oldwd))
  setwd(prov)
  sprintf("jachtveld_%s.*_%s.pdf", head(this_wbe$wbe, 1), this_layout) |>
    list.files(path = prov, pattern = _) -> files
  sprintf("wbe_%s_%s.zip", head(this_wbe$wbe, 1), this_layout) |>
    zip(files = files, zip = "zip")
  file.remove(files)
  return(invisible(NULL))
}

render_province <- function(
  this_layout = "luchtfoto", these_grounds, target_folder
) {
  file.path(
    target_folder, tolower(this_layout), head(these_grounds$prov, 1)
  ) |>
    list.files(pattern = ".*.zip") |>
    gsub(pattern = "wbe_(.*)_.*", replacement = "\\1") -> done
  these_grounds <- these_grounds[!these_grounds$wbe %in% done, ]
  for (wbe in unique(these_grounds$wbe)) {
    render_wbe(
      this_layout = this_layout, target_folder = target_folder,
      this_wbe = these_grounds[these_grounds$wbe == wbe, ]
    )
  }
  return(invisible(NULL))
}

render_layout <- function(
  this_layout = "luchtfoto", grounds, target_folder
) {
  for (prov in unique(grounds$prov)) {
    render_province(
      this_layout = this_layout, target_folder = target_folder,
      these_grounds = grounds[grounds$prov == prov, ]
    )
  }
  return(invisible(NULL))
}

render_layout(
  this_layout = "luchtfoto", grounds = hunting_grounds,
  target_folder = target_folder
)
render_layout(
  this_layout = "OSM", grounds = hunting_grounds,
  target_folder = target_folder
)
render_layout(
  this_layout = "Cartoweb", grounds = hunting_grounds,
  target_folder = target_folder
)

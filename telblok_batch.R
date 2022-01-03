renv::restore()
library(tidyverse)
library(sf)
library(here)
library(jsonlite)

target_folder <- normalizePath(file.path("~", "patrijs"))
source_folder <- here("steekproef")

target_folder %>%
  list.files(pattern = "jachtveld_.*.pdf", recursive = TRUE) %>%
  as_tibble() %>%
  extract(.data$value, c("VELDID", "layout"), ".*_(.*)_(.*).pdf") -> done

here(source_folder, "telblok.gpkg") %>%
  read_sf() %>%
  st_drop_geometry() %>%
  filter(!is.na(.data$WBENR)) %>%
  distinct(.data$VELDID) %>%
  expand_grid(layout = c("OSM", "luchtfoto")) %>%
  anti_join(done, by = c("VELDID", "layout")) %>%
  arrange(.data$VELDID, .data$layout) %>%
  transmute(
    PARAMETERS = map2(.data$layout, .data$VELDID, ~list(
      LAYOUT = sprintf("\'%s\'", .x),
      FILTER_EXPRESSION = sprintf("'\"VELDID\" = \\'%s\\''", .y),
      COVERAGE_LAYER = sprintf(
        "\'%s|layername=telblok\'", here(source_folder, "telblok.gpkg")
      ),
      SORTBY_EXPRESSION = "'\"id\"'"
    )),
    OUTPUTS = map2(.data$layout, .data$VELDID, ~list(
      OUTPUT = sprintf(
        "\'%s/%s/jachtveld_%s_%s.pdf'", target_folder, .x, .y, .x
      )
    ))
  ) %>%
  transmute(
    cmd = map2(
      .data$PARAMETERS, .data$OUTPUTS, ~list(PARAMETERS = .x, OUTPUTS = .y)
    )
  ) %>%
  pull(.data$cmd) %>%
  head(2000) %>%
  toJSON(auto_unbox = TRUE) %>%
  writeLines(here(source_folder, "batch.json"))

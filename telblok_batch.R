renv::restore()
library(tidyverse)
library(sf)
library(here)
library(jsonlite)

layout <- c("Cartoweb", "luchtfoto", "OSM")
layout <- tail(layout, -1)
provincie <- c("WEVL", "OOVL", "ANTW", "LIMB", "VLBR")
target_folder <- normalizePath(file.path("~", "patrijs"))
expand_grid(target_folder, layout, provincie) %>%
  transmute(path = file.path(target_folder, layout, provincie)) %>%
  pull(.data$path) %>%
  walk(dir.create, showWarnings = FALSE, recursive = TRUE)

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
  expand_grid(layout = layout) %>%
  anti_join(done, by = c("VELDID", "layout")) %>%
  arrange(.data$layout, desc(.data$VELDID)) %>%
  head(2000) %>%
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
        "\'%s/%s/%s/jachtveld_%s_%s.pdf'", target_folder, .x,
        provincie[as.integer(str_sub(.y, 1, 1))], .y, .x
      )
    ))
  ) %>%
  transmute(
    cmd = map2(
      .data$PARAMETERS, .data$OUTPUTS, ~list(PARAMETERS = .x, OUTPUTS = .y)
    )
  ) %>%
  pull(.data$cmd) %>%
  toJSON(auto_unbox = TRUE) %>%
  writeLines(here(source_folder, "batch.json"))

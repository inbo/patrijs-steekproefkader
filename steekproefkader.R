library(here)
library(git2rdata)
library(sf)
library(tidyverse)
library(qgisprocess)
qgis_configure()

target_folder <- here("steekproef")
bwk <- here("downloads", "bwkhab.shp")
jachtgebieden <- here("downloads", "jachtter.shp")
vlaanderen <- here("downloads", "refgew.shp")
wegen <- here("downloads", "wegsegment.shp")
waterlopen <- here("downloads", "wlas.shp")
spoorwegen <- here("downloads", "spoorweg.shp")

if (!file.exists(file.path(target_folder, "open_ruimte.gpkg"))) {
  read_vc("bwk_eenheid", root = here("downloads")) %>%
    filter(.data$open) %>%
    pull(.data$eenheid) -> open_eenheden
  qgis_run_algorithm(
    "native:extractbyexpression",
    INPUT = bwk,
    EXPRESSION = paste(
      sprintf("EENH1 = '%s'", open_eenheden),
      collapse = " OR "
    )
  ) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "open", FORMULA = "1"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(algorithm = "native:dissolve", FIELD = "open")) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(algorithm = "native:multiparttosingleparts")) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "open",
        FORMULA = "@row_number"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:buffer", DISTANCE = -0.1, DISSOLVE = FALSE,
        END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    unclass() %>%
    read_sf() %>%
    st_transform(crs = 31370) %>%
    st_write(
      dsn = file.path(target_folder, "open_ruimte.gpkg"),
      delete_dsn = file.exists(
        file.path(target_folder, "open_ruimte.gpkg")
      )
    )
}

if (!file.exists(file.path(target_folder, "velden.gpkg"))) {
  jachtgebieden %>%
    read_sf() %>%
    filter(!is.na(.data$WBENR)) %>%
    st_transform(crs = 31370) %>%
    select(wbe = .data$WBENR, veld = .data$VELDID) -> jacht
  qgis_run_algorithm(
    "native:buffer",
    INPUT = jacht, DISTANCE = -0.1, DISSOLVE = FALSE,
    END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5
  ) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:dissolve",
        FIELD = c("wbe", "veld"),
        OUTPUT = file.path(target_folder, "velden.gpkg")
      )
    ) %>%
    do.call(what = qgis_run_algorithm)
}

message("kader 1")
if (!file.exists(file.path(target_folder, "kader_01.gpkg"))) {
  qgis_run_algorithm(
    "native:intersection",
    INPUT = file.path(target_folder, "velden.gpkg"),
    INPUT_FIELDS = c("wbe", "veld"),
    OVERLAY = file.path(target_folder, "open_ruimte.gpkg"),
    OVERLAY_FIELDS = "open_id",
    OVERLAY_FIELDS_PREFIX = ""
  ) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(algorithm = "native:multiparttosingleparts")) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de breedte van de bounding box in hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "dx",
        FORMULA = "bounds_width($geometry) / 100"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de hoogte van de bounding box in hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "dy",
        FORMULA = "bounds_height($geometry) / 100"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de oppervlakte in ha
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "ha",
        FORMULA = "$area / 10000"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bepaal polygonen breder of hoger dan 27 hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "te_breed",
        FORMULA = "if(if( dx > dy,dx, dy) > 27, 1, 0)", FIELD_TYPE = 1
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bepaal polygonen breder of hoger dan 19 hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "te_hoog",
        FORMULA = "if(if( dx > dy, dy, dx) > 19, 1, 0)", FIELD_TYPE = 1
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de verhouding oppervlakte / bounding box
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "ratio",
        FORMULA = "ha / dx / dy",
        OUTPUT = sprintf("%s/kader_01.gpkg", target_folder)
      )
    ) %>%
    do.call(what = qgis_run_algorithm)
}

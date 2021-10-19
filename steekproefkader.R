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

if (!file.exists(file.path(target_folder, "level_01.gpkg"))) {
  wegen %>%
    read_sf() %>%
    filter(LBLWEGCAT %in% c("hoofdweg", "primaire weg I")) %>%
    st_transform(crs = 31370) %>%
    select(LBLWEGCAT) -> hoofdweg
  waterlopen %>%
    read_sf() %>%
    filter(LBLCATC %in% c("Bevaarbaar")) %>%
    st_transform(crs = 31370) %>%
    select(LBLCATC) -> bevaarbaar
  vlaanderen %>%
    read_sf() %>%
    st_transform(crs = 31370) %>%
    st_write(
      dsn = file.path(target_folder, "vlaanderen.shp"),
      delete_dsn = file.exists(
        file.path(target_folder, "vlaanderen.shp")
      )
    )
  qgis_run_algorithm(
    "native:buffer", INPUT = bevaarbaar, DISTANCE = 20, DISSOLVE = TRUE,
    END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5
  ) %>%
    qgis_output("OUTPUT") %>%
    as.character() -> bevaarbaar
  qgis_run_algorithm(
    "native:buffer", INPUT = hoofdweg, DISTANCE = 20, DISSOLVE = TRUE,
    END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5
  ) %>%
    qgis_output("OUTPUT") %>%
    setNames("OVERLAY") %>%
    c(
      list(
        algorithm = "native:difference",
        INPUT = file.path(target_folder, "vlaanderen.shp")
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(algorithm = "native:difference", OVERLAY = bevaarbaar)) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(algorithm = "native:multiparttosingleparts")) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:buffer", DISTANCE = 19.8, DISSOLVE = FALSE,
        END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    read_sf() %>%
    mutate(level1 = row_number()) %>%
    select(-OIDN) %>%
    st_write(
      dsn = file.path(target_folder, "level_01.gpkg"),
      delete_dsn = file.exists(
        file.path(target_folder, "level_01.gpkg")
      )
    )
}

refine_level <- function(
    current_level, target_folder, split_laag, split_var, split_val
) {
  # selecteer nieuwe grenzen
  qgis_run_algorithm(
    "native:extractbyexpression",
    INPUT = split_laag,
    EXPRESSION = paste0(split_var, " = '", split_val, "'", collapse = " OR ")
  ) %>%
    qgis_output("OUTPUT") %>%
    unclass() -> split_laag
  # selecteer te verkleinen polygonen van steekproefkader
  qgis_run_algorithm(
    "native:extractbyexpression",
    INPUT = sprintf("%s/kader_%02i.gpkg", target_folder, current_level),
    EXPRESSION =
      "ha > 150 OR te_breed = 1 OR te_hoog = 1 OR (ratio < 0.1 AND ha > 1)"
  ) %>%
    qgis_output("OUTPUT") %>%
    # selecteer de overeenkomstige eiland polygonen
    setNames("INTERSECT") %>%
    c(
      list(
        algorithm = "native:extractbylocation",
        INPUT = sprintf("%s/level_%02i.gpkg", target_folder, current_level)
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    unclass() -> level_selectie
  # snijd de beschikbare grenzen bij aan de hand van de geselecteerde eiland
  # polygonen
  qgis_run_algorithm(
    "native:clip", INPUT = split_laag, OVERLAY = level_selectie
  ) %>%
    qgis_output("OUTPUT") %>%
    # buffer de overgebleven grenzen
    setNames("INPUT") %>%
    c(list(algorithm = "native:buffer", DISTANCE = 10)) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # knip de buffers uit de eiland polygonen
    setNames("OVERLAY") %>%
    c(
      list(
        algorithm = "native:difference",
        INPUT = sprintf("%s/level_%02i.gpkg", target_folder, current_level)
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # split de nieuwe eilandpolygonen in afzonderlijke polygonen
    setNames("INPUT") %>%
    c(list(algorithm = "native:multiparttosingleparts")) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # herstel buffer
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:buffer", DISTANCE = 9.8, DISSOLVE = FALSE,
        END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # voeg een nieuwe id toe aan de eilandpolygonen
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:addautoincrementalfield",
        FIELD_NAME = paste0("level", current_level + 1),
        OUTPUT = sprintf("%s/level_%02i.gpkg", target_folder, current_level + 1)
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # versnij de eilandpolygonen met het basissteekproefkader
    setNames("OVERLAY") %>%
    c(
      list(
        algorithm = "native:intersection",
        INPUT = file.path(target_folder, "kader_01.gpkg"),
        INPUT_FIELDS = c("wbe", "veld", "open_id"),
        OVERLAY_FIELDS = paste0("level", seq_len(current_level + 1)),
        OVERLAY_FIELDS_PREFIX = ""
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # zet het steekproefkader om naar enkelvoudige polygonen
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
        OUTPUT = sprintf("%s/kader_%02i.gpkg", target_folder, current_level + 1)
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT")
}

message("kader 2")
if (!file.exists(file.path(target_folder, "kader_02.gpkg"))) {
  refine_level(
    current_level = 1, split_laag = waterlopen, split_var = "LBLCATC",
    split_val = "Geklasseerd, eerste categorie", target_folder = target_folder
  )
}

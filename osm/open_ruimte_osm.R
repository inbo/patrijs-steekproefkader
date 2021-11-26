library(here)
library(osmextract)
library(tidyverse)
library(qgisprocess)
qgis_configure()

download_folder <- here("downloads")
target_folder <- here("osm")
dir.create(target_folder, showWarnings = FALSE)

vlaanderen <- here(target_folder, "vlaanderen.gpkg")
jacht <- here(target_folder, "jacht.gpkg")
landuse <- here(target_folder, "landuse.gpkg")
natural <- here(target_folder, "natural.gpkg")
leisure <- here(target_folder, "leisure.gpkg")

farmland <- here(target_folder, "landuse_farmland.gpkg")
farmyard <- here(target_folder, "landuse_farmyard.gpkg")
grass <- here(target_folder, "landuse_grass.gpkg")
industrial <- here(target_folder, "landuse_industrial.gpkg")
meadow <- here(target_folder, "landuse_meadow.gpkg")
orchard <- here(target_folder, "landuse_orchard.gpkg")
residential <- here(target_folder, "landuse_residential.gpkg")
wood <- here(target_folder, "landuse_wood.gpkg")

natural_grass <- here(target_folder, "natural_grass.gpkg")
natural_wetland <- here(target_folder, "natural_wetland.gpkg")
natural_wood <- here(target_folder, "natural_wood.gpkg")

farmland_d <- here(target_folder, "landuse_farmland_d.gpkg")
grass_d <- here(target_folder, "landuse_grass_d.gpkg")
meadow_d <- here(target_folder, "landuse_meadow_d.gpkg")
orchard_d <- here(target_folder, "landuse_orchard_d.gpkg")

natural_grass_d <- here(target_folder, "natural_grass_d.gpkg")
natural_wetland_d <- here(target_folder, "natural_wetland_d.gpkg")

open_ruimte_max <- here(target_folder, "open_ruimte_max.gpkg")
open_ruimte_osm <- here(target_folder, "open_ruimte_osm.gpkg")

if (!file_test("-f", vlaanderen)) {
  here(download_folder, "refgew.shp") %>%
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
      algorithm = "native:reprojectlayer", OUTPUT = vlaanderen,
      TARGET_CRS = "PROJ4:+proj=longlat +datum=WGS84 +no_defs"
    )) %>%
    do.call(what = qgis_run_algorithm)
}

if (!file_test("-f", jacht)) {
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
    # setNames("INPUT") %>%
    # c(list(
    #   algorithm = "native:retainfields", OUTPUT = qgis_tmp_vector(),
    #   FIELDS = c("VELDID", "WBENR")
    # )) %>%
    # do.call(what = qgis_run_algorithm) %>%
    # qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:reprojectlayer", OUTPUT = jacht,
      TARGET_CRS = "PROJ4:+proj=longlat +datum=WGS84 +no_defs"
    )) %>%
    do.call(what = qgis_run_algorithm)
}

if (!file_test("-f", natural)) {
  osm_source <- oe_match("Belgium")
  osm_pbf <- oe_download(
    file_url = osm_source$url, file_size = osm_source$file_size
  )
  osm_gpkg <- oe_vectortranslate(file_path = osm_pbf, layer = "multipolygons")

  # select only non NULL landuse
  osm_gpkg %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "landuse", VALUE = NULL,
      OPERATOR = "is not null", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:clip", OVERLAY = vlaanderen,
        OUTPUT = qgis_tmp_vector()
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:retainfields", OUTPUT = landuse,
      FIELDS = c("osm_id", "landuse", "other_tags")
    )) %>%
    do.call(what = qgis_run_algorithm)

  # select only non NULL natural
  osm_gpkg %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "natural", VALUE = NULL,
      OPERATOR = "is not null", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:clip", OVERLAY = vlaanderen,
        OUTPUT = qgis_tmp_vector()
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:retainfields",
        FIELDS = c("osm_id", "natural", "other_tags"),
        OUTPUT = natural
      )
    ) %>%
    do.call(what = qgis_run_algorithm)

  # select only non NULL leisure
  osm_gpkg %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "leisure", VALUE = NULL,
      OPERATOR = "is not null", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:clip", OVERLAY = vlaanderen,
        OUTPUT = qgis_tmp_vector()
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:retainfields",
        FIELDS = c("osm_id", "leisure", "other_tags"),
        OUTPUT = leisure
      )
    ) %>%
    do.call(what = qgis_run_algorithm)

  qgis_tmp_clean()
}

if (!file_test("-f", industrial)) {
  landuse %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "landuse",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "grass",
      FAIL_OUTPUT = grass
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "landuse",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "meadow",
      FAIL_OUTPUT = meadow
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "landuse",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "farmland",
      FAIL_OUTPUT = farmland
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "landuse",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "orchard",
      FAIL_OUTPUT = orchard
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "landuse",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "residential",
      FAIL_OUTPUT = residential
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "landuse",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "farmyard",
      FAIL_OUTPUT = farmyard
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "landuse",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "forest",
      FAIL_OUTPUT = wood
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "landuse",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "industrial",
      FAIL_OUTPUT = industrial
    )) %>%
    do.call(what = qgis_run_algorithm)

  qgis_tmp_clean()
}

if (!file_test("-f", natural_grass)) {
  natural %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "natural",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "grassland",
      FAIL_OUTPUT = natural_grass
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "natural",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "wetland",
      FAIL_OUTPUT = natural_wetland
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "natural",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "wood",
      FAIL_OUTPUT = natural_wood
    )) %>%
    do.call(what = qgis_run_algorithm)

  qgis_tmp_clean()
}

if (!file_test("-f", natural_grass_d)) {
  natural_grass %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:renametablefield", FIELD = "natural",
      NEW_NAME = "landuse", OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:dissolve", FIELD = "landuse",
      OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:multiparttosingleparts", OUTPUT = natural_grass_d
    )) %>%
    do.call(what = qgis_run_algorithm)

  qgis_tmp_clean()
}

if (!file_test("-f", natural_wetland_d)) {
  wetland_no_other <- qgis_tmp_vector()
  natural_wetland %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "other_tags",
      VALUE = NULL, OPERATOR = "is not null", OUTPUT = qgis_tmp_vector(),
      FAIL_OUTPUT = wetland_no_other
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "other_tags",
      VALUE = "wet_meadow", OPERATOR = "contains", OUTPUT = qgis_tmp_vector(),
      FAIL_OUTPUT = NULL
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    unclass() %>%
    qgis_list_input(wetland_no_other) %>%
    list() %>%
    setNames("LAYERS") %>%
    c(list(
      algorithm = "native:mergevectorlayers", OUTPUT = qgis_tmp_vector(),
      CRS = "PROJ4:+proj=longlat +datum=WGS84 +no_defs"
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:renametablefield", FIELD = "natural",
      NEW_NAME = "landuse", OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:dissolve", FIELD = "landuse",
      OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:multiparttosingleparts", OUTPUT = natural_wetland_d
    )) %>%
    do.call(what = qgis_run_algorithm)

  qgis_tmp_clean()
}

if (!file_test("-f", grass_d)) {
  grass %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:dissolve", FIELD = "landuse",
      OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:multiparttosingleparts", OUTPUT = grass_d
    )) %>%
    do.call(what = qgis_run_algorithm)

  qgis_tmp_clean()
}

if (!file_test("-f", farmland_d)) {
  farmland %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:dissolve", FIELD = "landuse",
      OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:multiparttosingleparts", OUTPUT = farmland_d
    )) %>%
    do.call(what = qgis_run_algorithm)

  qgis_tmp_clean()
}

if (!file_test("-f", meadow_d)) {
  meadow %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:dissolve", FIELD = "landuse",
      OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:multiparttosingleparts", OUTPUT = meadow_d
    )) %>%
    do.call(what = qgis_run_algorithm)

  qgis_tmp_clean()
}

if (!file_test("-f", orchard_d)) {
  orchard %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:dissolve", FIELD = "landuse",
      OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:multiparttosingleparts", OUTPUT = orchard_d
    )) %>%
    do.call(what = qgis_run_algorithm)

  qgis_tmp_clean()
}

if (!file_test("-f", open_ruimte_max)) {
  farmland_d %>%
    qgis_list_input(
      grass_d, meadow_d, orchard_d, natural_grass_d, natural_wetland_d
    ) %>%
    list() %>%
    setNames("LAYERS") %>%
    c(list(
      algorithm = "native:mergevectorlayers", OUTPUT = qgis_tmp_vector(),
      CRS = "PROJ4:+proj=longlat +datum=WGS84 +no_defs"
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:fieldcalculator", FIELD_NAME = "open", FORMULA = 1,
      FIELD_TYPE = "Integer", FIELD_LENGTH = 1, FIELD_PRECISION = 0,
      OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:dissolve", FIELD = "open",
      OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector(),
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:intersection", OVERLAY = jacht,
      INPUT_FIELDS = NULL, OVERLAY_FIELDS = c("VELDID", "WBENR"),
      OUTPUT = open_ruimte_max
    )) %>%
    do.call(what = qgis_run_algorithm)
}

if (!file_test("-f", open_ruimte_osm)) {
  open_ruimte_f <- qgis_tmp_vector()
  open_ruimte_i <- qgis_tmp_vector()
  open_ruimte_l <- qgis_tmp_vector()
  open_ruimte_r <- qgis_tmp_vector()
  open_ruimte_w <- qgis_tmp_vector()
  open_ruimte_wn <- qgis_tmp_vector()
  residential %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbylocation", INTERSECT = open_ruimte_max,
      PREDICATE = 6, OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("OVERLAY") %>%
    c(list(
      algorithm = "native:difference", INPUT = open_ruimte_max,
      OUTPUT = open_ruimte_r
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INTERSECT") %>%
    c(list(
      algorithm = "native:extractbylocation", INPUT = natural_wood,
      PREDICATE = 6, OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("OVERLAY") %>%
    c(list(
      algorithm = "native:difference", INPUT = open_ruimte_r,
      OUTPUT = open_ruimte_wn
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INTERSECT") %>%
    c(list(
      algorithm = "native:extractbylocation", INPUT = wood,
      PREDICATE = 6, OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("OVERLAY") %>%
    c(list(
      algorithm = "native:difference", INPUT = open_ruimte_wn,
      OUTPUT = open_ruimte_w
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INTERSECT") %>%
    c(list(
      algorithm = "native:extractbylocation", INPUT = farmyard,
      PREDICATE = 6, OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("OVERLAY") %>%
    c(list(
      algorithm = "native:difference", INPUT = open_ruimte_w,
      OUTPUT = open_ruimte_f
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INTERSECT") %>%
    c(list(
      algorithm = "native:extractbylocation", INPUT = industrial,
      PREDICATE = 6, OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("OVERLAY") %>%
    c(list(
      algorithm = "native:difference", INPUT = open_ruimte_f,
    #   OUTPUT = open_ruimte_i
    # )) %>%
    # do.call(what = qgis_run_algorithm) %>%
    # qgis_output("OUTPUT") %>%
    # setNames("INTERSECT") %>%
    # c(list(
    #   algorithm = "native:extractbylocation", INPUT = leisure,
    #   PREDICATE = 6, OUTPUT = qgis_tmp_vector()
    # )) %>%
    # do.call(what = qgis_run_algorithm) %>%
    # qgis_output("OUTPUT") %>%
    # setNames("OVERLAY") %>%
    # c(list(
    #   algorithm = "native:difference", INPUT = open_ruimte_i,
      OUTPUT = open_ruimte_osm
    )) %>%
    do.call(what = qgis_run_algorithm)
}

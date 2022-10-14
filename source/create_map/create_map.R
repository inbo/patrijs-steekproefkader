renv::restore()
library(here)
library(osmextract)
library(tidyverse)
library(qgisprocess)
qgis_configure()

download_folder <- here("data", "downloads")
target_folder <- here("data", "open_area")
dir.create(target_folder, showWarnings = FALSE)

source(here("source", "create_map", "download.R"))
osm_pbf <- here(download_folder, "geofabrik_belgium-latest.osm.pbf")

jacht <- here(target_folder, "jacht.gpkg")
if (!file_test("-f", jacht)) {
  source(here("source", "create_map", "hunting_grounds.R"))
}

# extract landuse, landcover and natural

landuse <- here(target_folder, "landuse.gpkg")
landcover <- here(target_folder, "landcover.gpkg")
natural <- here(target_folder, "natural.gpkg")

if (!file_test("-f", natural)) {
  osm_gpkg <- oe_vectortranslate(file_path = osm_pbf, layer = "multipolygons")

  # select only non NULL landuse
  osm_gpkg %>%
    paste0("|layername=multipolygons") %>%
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
    c(list(
      algorithm = "native:clip", OVERLAY = jacht, OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:retainfields", OUTPUT = landuse,
      FIELDS = c("osm_id", "landuse", "other_tags")
    )) %>%
    do.call(what = qgis_run_algorithm)

  # select only landcover
  osm_gpkg %>%
    paste0("|layername=multipolygons") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "other_tags",
      VALUE = "landcover",
      OPERATOR = "contains", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
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
    c(list(
      algorithm = "native:clip", OVERLAY = jacht, OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:retainfields", OUTPUT = landcover,
      FIELDS = c("osm_id", "other_tags")
    )) %>%
    do.call(what = qgis_run_algorithm)

  # select only non NULL natural
  osm_gpkg %>%
    paste0("|layername=multipolygons") %>%
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
    c(list(
      algorithm = "native:clip", OVERLAY = jacht, OUTPUT = qgis_tmp_vector()
    )) %>%
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

  qgis_tmp_clean()
}

# extract relevant landuse categories

animal_keeping <- here(target_folder, "landuse_animal_keeping.gpkg")
farmland <- here(target_folder, "landuse_farmland.gpkg")
farmyard <- here(target_folder, "landuse_farmyard.gpkg")
forest <- here(target_folder, "landuse_forest.gpkg")
grass <- here(target_folder, "landuse_grass.gpkg")
industrial <- here(target_folder, "landuse_industrial.gpkg")
meadow <- here(target_folder, "landuse_meadow.gpkg")
orchard <- here(target_folder, "landuse_orchard.gpkg")
residential <- here(target_folder, "landuse_residential.gpkg")
vineyard <- here(target_folder, "landuse_vineyard.gpkg")

if (!file_test("-f", vineyard)) {
  landuse %>%
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
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "meadow",
      FAIL_OUTPUT = meadow
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
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "grass",
      FAIL_OUTPUT = grass
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "landuse",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "forest",
      FAIL_OUTPUT = forest
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "landuse",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "industrial",
      FAIL_OUTPUT = industrial
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "landuse",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "animal_keeping",
      FAIL_OUTPUT = animal_keeping
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
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "vineyard",
      FAIL_OUTPUT = vineyard
    )) %>%
    do.call(what = qgis_run_algorithm)

  qgis_tmp_clean()
}

# extract relevant natural categories

natural_grassland <- here(target_folder, "natural_grassland.gpkg")
natural_wetland <- here(target_folder, "natural_wetland.gpkg")
natural_wood <- here(target_folder, "natural_wood.gpkg")

if (!file_test("-f", natural_grassland)) {
  natural %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "natural",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "grassland",
      FAIL_OUTPUT = natural_grassland
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

# refine wetland
# keep only meadow = wet_meadow or meadow = NULL
wetland_no_other <- qgis_tmp_vector()
natural_wetland %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:fieldcalculator", FIELD_NAME = "meadow",
    FORMULA = 'regexp_substr("other_tags", \'.*meadow"=>"(.*?)".*\')',
    OUTPUT = qgis_tmp_vector(), FIELD_TYPE = "Text (string)"
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "meadow",
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
    algorithm = "native:mergevectorlayers", OUTPUT = natural_wetland,
    CRS = "PROJ4:+proj=longlat +datum=WGS84 +no_defs"
  )) %>%
  do.call(what = qgis_run_algorithm)

# extract relevant landcover categories

landcover_grass <- here(target_folder, "landcover_grass.gpkg")

if (!file_test("-f", landcover_grass)) {
  landcover %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:fieldcalculator", FIELD_NAME = "landcover",
      FORMULA = 'regexp_substr("other_tags", \'.*landcover"=>"(.*?)".*\')',
      OUTPUT = qgis_tmp_vector(), FIELD_TYPE = "Text (string)"
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:extractbyattribute", FIELD = "landcover",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "grass",
      FAIL_OUTPUT = landcover_grass
    )) %>%
    do.call(what = qgis_run_algorithm)

  qgis_tmp_clean()
}

# simplify layers by joining adjacent polygons and keeping only one field

list.files(
  target_folder, pattern = "^(landuse|landcover|natural)_[a-z]{2}",
  full.names = TRUE
) -> to_do
list.files(
  target_folder, pattern = "^(landuse|landcover|natural)_d_[a-z]{2}",
  full.names = TRUE
) %>%
  str_replace("(landuse|landcover|natural)_d_([a-z]{2})", "\\1_\\2") -> done
to_do[!to_do %in% done] %>%
  walk(
    function(i) {
      i %>%
        setNames("INPUT") %>%
        c(list(
          algorithm = "native:fieldcalculator", FIELD_NAME = "open",
          FORMULA = 1, FIELD_TYPE = "Integer (32 bit)", FIELD_LENGTH = 1,
          FIELD_PRECISION = 0, OUTPUT = qgis_tmp_vector()
        )) %>%
        do.call(what = qgis_run_algorithm) %>%
        qgis_output("OUTPUT") %>%
        setNames("INPUT") %>%
        c(list(
          algorithm = "native:retainfields", OUTPUT = qgis_tmp_vector(),
          FIELDS = "open"
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
          algorithm = "native:multiparttosingleparts",
          OUTPUT = str_replace(
            i, "(landuse|landcover|natural)_([a-z]{2}.*)", "\\1_d_\\2"
          )
        )) %>%
        do.call(what = qgis_run_algorithm)
      qgis_tmp_clean()
    }
  )

# positive selection
c(
  "animal_keeping", "farmland", "grass", "meadow", "orchard", "vineyard",
  "wetland"
) %>%
  paste(collapse = "|") %>%
  sprintf(fmt = "(%s)") %>%
  str_subset(
    string = list.files(target_folder, pattern = "_d_", full.names = TRUE)
  ) %>%
  as.list() %>%
  do.call(what = "qgis_list_input") %>%
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
    algorithm = "native:dissolve", FIELD = "open",
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:multiparttosingleparts",
    OUTPUT = here(target_folder, "open_ruimte_max.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm)
qgis_tmp_clean()


# negative selection
c("farmyard", "forest", "industrial", "residential", "wood") %>%
  paste(collapse = "|") %>%
  sprintf(fmt = "(%s)") %>%
  str_subset(
    string = list.files(target_folder, pattern = "_d_", full.names = TRUE)
  ) -> to_exclude
current_input <- here(target_folder, "open_ruimte_max.gpkg")
for (current_exclude in to_exclude) {
  current_input %>%
    setNames("INTERSECT") %>%
    c(list(
      algorithm = "native:extractbylocation", INPUT = current_exclude,
      PREDICATE = 6, OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("OVERLAY") %>%
    c(list(
      algorithm = "native:difference", INPUT = current_input,
      OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    unclass() -> current_input
}
current_input %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:intersection", OVERLAY = jacht,
    INPUT_FIELDS = NULL, OVERLAY_FIELDS = c("VELDID", "WBENR"),
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:retainfields",
    OUTPUT = here(target_folder, "open_ruimte.gpkg"),
    FIELDS = c("VELDID", "WBENR")
  )) %>%
  do.call(what = qgis_run_algorithm)
qgis_tmp_clean()

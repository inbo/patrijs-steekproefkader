library(here)
library(tidyverse)
library(osmextract)
library(qgisprocess)
qgis_configure()

target_folder <- here("steekproef")
dir.create(target_folder, showWarnings = FALSE)

here("open_ruimte", "open_ruimte.gpkg") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "WBENR", VALUE = NULL,
    OPERATOR = "is not null", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:reprojectlayer",
    OUTPUT = here(target_folder, "open_ruimte_lambert75.gpkg"),
    TARGET_CRS = paste(
      "PROJ4:+proj=lcc +lat_0=90 +lon_0=4.36748666666667",
      "+lat_1=51.1666672333333 +lat_2=49.8333339 +x_0=150000.013",
      "+y_0=5400088.438 +ellps=intl",
      "+towgs84=-99.059,53.322,-112.486,0.419,-0.83,1.885,-1",
      "+units=m +no_defs"
    )
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(algorithm = "native:dissolve", FIELD = "VELDID")) %>%
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
  # determine which polygons are too large, too wide or too high
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
    FORMULA = "if(
      ha > 150 OR
        (dx > dy AND (dx > 27 OR dy > 19)) OR
        (dy > dx AND (dy > 27 OR dx > 19)),
      0, 1
    )", FIELD_TYPE = 1,
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  # set small polygons aside
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "ok",
    OPERATOR = "=", OUTPUT = here(target_folder, "to_refine.gpkg"), VALUE = 0,
    FAIL_OUTPUT = here(target_folder, "open_ruimte_ok_1.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm)

download_folder <- here("downloads")
osm_pbf <- here(download_folder, "geofabrik_belgium-latest.osm.pbf")
osm_gpkg <- oe_vectortranslate(file_path = osm_pbf, layer = "lines")

osm_gpkg %>%
  paste0("|layername=lines") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "highway", VALUE = NULL,
    OPERATOR = "is not null", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:retainfields", OUTPUT = qgis_tmp_vector(),
    FIELDS = "highway"
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:clip", OVERLAY = here(target_folder, "to_refine.gpkg"),
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "highway",
    OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "residential",
    FAIL_OUTPUT = here(target_folder, "highway_residential.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "highway",
    OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "unclassified",
    FAIL_OUTPUT = here(target_folder, "highway_unclassified.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "highway",
    OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "tertiary",
    FAIL_OUTPUT = here(target_folder, "highway_tertiary.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "highway",
    OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "secondary",
    FAIL_OUTPUT = here(target_folder, "highway_secondary.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "highway",
    OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "track",
    FAIL_OUTPUT = here(target_folder, "highway_track.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "highway",
    OPERATOR = "≠", OUTPUT = qgis_tmp_vector(),
    VALUE = "path", FAIL_OUTPUT = here(target_folder, "highway_path.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "highway",
    OPERATOR = "≠", OUTPUT = here(target_folder, "highway_other.gpkg"),
    VALUE = "service", FAIL_OUTPUT = here(target_folder, "highway_service.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm)

osm_gpkg %>%
  paste0("|layername=lines") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "waterway", VALUE = NULL,
    OPERATOR = "is not null", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:retainfields", OUTPUT = qgis_tmp_vector(),
    FIELDS = "waterway"
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:clip", OVERLAY = here(target_folder, "to_refine.gpkg"),
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "waterway",
    OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "stream",
    FAIL_OUTPUT = here(target_folder, "waterway_stream.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "waterway",
    OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "ditch",
    FAIL_OUTPUT = here(target_folder, "waterway_ditch.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "waterway",
    OPERATOR = "≠", OUTPUT = here(target_folder, "waterway_other.gpkg"),
    FAIL_OUTPUT = here(target_folder, "waterway_drain.gpkg"), VALUE = "drain"
  )) %>%
  do.call(what = qgis_run_algorithm)

to_buffer <- list.files(
  target_folder, pattern = "^(high|water)way.*.gpkg", full.names = TRUE
)

for (i in to_buffer) {
  i %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:reprojectlayer",
      OUTPUT = qgis_tmp_vector(),
      TARGET_CRS = paste(
        "PROJ4:+proj=lcc +lat_0=90 +lon_0=4.36748666666667",
        "+lat_1=51.1666672333333 +lat_2=49.8333339 +x_0=150000.013",
        "+y_0=5400088.438 +ellps=intl",
        "+towgs84=-99.059,53.322,-112.486,0.419,-0.83,1.885,-1",
        "+units=m +no_defs"
      )
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:buffer", DISTANCE = 5, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = here(target_folder, paste0("buffer_", basename(i)))
    )) %>%
    do.call(what = qgis_run_algorithm)
}


here(target_folder, "open_ruimte_lambert75.gpkg") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:joinattributestable", FIELD = "VELDID",
    OUTPUT = qgis_tmp_vector(), INPUT_2 = here(target_folder, "to_refine.gpkg"),
    FIELD_2 = "VELDID", DISCARD_NONMATCHING = TRUE,
    METHOD = "Take attributes of the first matching feature only (one-to-one)",
    FIELDS_TO_COPY = "fid", PREFIX = "junk", NON_MATCHING = NULL
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  # determine which polygons are too large, too wide or too high
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
    FORMULA = "if(
      $area > 500000 OR
        bounds_width($geometry) > 1900 OR
        bounds_height($geometry) > 1900,
      0, 1
    )", FIELD_TYPE = 1,
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  # set small polygons aside
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "ok",
    OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
    FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_1.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  # clip large polygons by secondary highways
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:difference",
    OVERLAY = here(target_folder, "buffer_highway_secondary.gpkg"),
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
  # determine which polygons are too large, too wide or too high
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
    FORMULA = "if(
      $area > 500000 OR
        bounds_width($geometry) > 1900 OR
        bounds_height($geometry) > 1900,
      0, 1
    )", FIELD_TYPE = 1,
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  # set small polygons aside
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "ok",
    OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
    FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_2.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:difference",
    OVERLAY = here(target_folder, "buffer_highway_tertiary.gpkg"),
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
  # determine which polygons are too large, too wide or too high
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
    FORMULA = "if(
      $area > 500000 OR
        bounds_width($geometry) > 1900 OR
        bounds_height($geometry) > 1900,
      0, 1
    )", FIELD_TYPE = 1,
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  # set small polygons aside
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "ok",
    OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
    FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_3.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:difference",
    OVERLAY = here(target_folder, "buffer_waterway_stream.gpkg"),
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
  # determine which polygons are too large, too wide or too high
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
    FORMULA = "if(
      $area > 500000 OR
        bounds_width($geometry) > 1900 OR
        bounds_height($geometry) > 1900,
      0, 1
    )", FIELD_TYPE = 1,
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  # set small polygons aside
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "ok",
    OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
    FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_4.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:difference",
    OVERLAY = here(target_folder, "buffer_highway_unclassified.gpkg"),
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
  # determine which polygons are too large, too wide or too high
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
    FORMULA = "if(
      $area > 500000 OR
        bounds_width($geometry) > 1900 OR
        bounds_height($geometry) > 1900,
      0, 1
    )", FIELD_TYPE = 1,
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  # set small polygons aside
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "ok",
    OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
    FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_5.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:difference",
    OVERLAY = here(target_folder, "buffer_highway_track.gpkg"),
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
  # determine which polygons are too large, too wide or too high
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
    FORMULA = "if(
      $area > 500000 OR
        bounds_width($geometry) > 1900 OR
        bounds_height($geometry) > 1900,
      0, 1
    )", FIELD_TYPE = 1,
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  # set small polygons aside
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "ok",
    OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
    FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_6.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:difference",
    OVERLAY = here(target_folder, "buffer_waterway_ditch.gpkg"),
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
  # determine which polygons are too large, too wide or too high
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
    FORMULA = "if(
      $area > 500000 OR
        bounds_width($geometry) > 1900 OR
        bounds_height($geometry) > 1900,
      0, 1
    )", FIELD_TYPE = 1,
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  # set small polygons aside
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "ok",
    OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
    FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_7.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:difference",
    OVERLAY = here(target_folder, "buffer_waterway_drain.gpkg"),
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
  # determine which polygons are too large, too wide or too high
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
    FORMULA = "if(
      $area > 500000 OR
        bounds_width($geometry) > 1900 OR
        bounds_height($geometry) > 1900,
      0, 1
    )", FIELD_TYPE = 1,
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  # set small polygons aside
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "ok",
    OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
    FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_8.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:difference",
    OVERLAY = here(target_folder, "buffer_highway_path.gpkg"),
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
  # determine which polygons are too large, too wide or too high
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
    FORMULA = "if(
      $area > 500000 OR
        bounds_width($geometry) > 1900 OR
        bounds_height($geometry) > 1900,
      0, 1
    )", FIELD_TYPE = 1,
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  # set small polygons aside
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "ok",
    OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
    FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_9.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:difference",
    OVERLAY = here(target_folder, "buffer_highway_service.gpkg"),
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
  # determine which polygons are too large, too wide or too high
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
    FORMULA = "if(
      $area > 500000 OR
        bounds_width($geometry) > 1900 OR
        bounds_height($geometry) > 1900,
      0, 1
    )", FIELD_TYPE = 1,
    OUTPUT = qgis_tmp_vector()
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  # set small polygons aside
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:extractbyattribute", FIELD = "ok",
    OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
    FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_10.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(list(
    algorithm = "native:fieldcalculator", FIELD_NAME = "ha",
    FORMULA = "$area / 10000", FIELD_TYPE = 1,
    OUTPUT = here(target_folder, "open_ruimte_klein_rest.gpkg")
  )) %>%
  do.call(what = qgis_run_algorithm)

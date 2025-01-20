renv::restore()
library(cluster)
library(here)
library(osmextract)
library(qgisprocess)
library(sf)
library(tidyverse)
qgis_configure()
source("source/create_map/functions.R")

target_folder <- here("data", "sampling")
dir.create(target_folder, showWarnings = FALSE)

# check the size of the open area by hunting ground
# when small enough for a single sample area place it in open_ruimte_ok_1
# otherwise place it in to_refine
if (!file_test("-f", here(target_folder, "to_refine.gpkg"))) {
  here("data", "open_area", "open_ruimte.gpkg") |>
    setNames("INPUT") |>
    qgis_run_algorithm_p(
      algorithm = "native:reprojectlayer",
      OUTPUT = qgis_tmp_vector(),
      TARGET_CRS = paste(
        "PROJ4:+proj=lcc +lat_0=90 +lon_0=4.36748666666667",
        "+lat_1=51.1666672333333 +lat_2=49.8333339 +x_0=150000.013",
        "+y_0=5400088.438 +ellps=intl",
        "+towgs84=-99.059,53.322,-112.486,0.419,-0.83,1.885,-1",
        "+units=m +no_defs"
      )
    ) |>
    # buffer with zero distance to fix geometry
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = here(target_folder, "open_ruimte_lambert75.gpkg")
    ) |>
    # create one polygon per hunting ground
    qgis_run_algorithm_p(
      algorithm = "native:dissolve", FIELD = "VELDID"
    ) |>
    # buffer with zero distance to fix geometry
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector()
    ) |>
    # calculate the with of the bounding box in hm
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "dx",
      FORMULA = "bounds_width($geometry) / 100",
      FIELD_TYPE = "Decimal (double)", OUTPUT = qgis_tmp_vector()
    ) |>
    # calculate the height of the bounding box in hm
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "dy",
      FORMULA = "bounds_height($geometry) / 100",
      FIELD_TYPE = "Decimal (double)", OUTPUT = qgis_tmp_vector()
    ) |>
    # calculate the open area in ha
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ha",
      FORMULA = "$area / 10000", FIELD_TYPE = "Decimal (double)", # nolint
      OUTPUT = qgis_tmp_vector()
    ) |>
    # determine which polygons are too large, too wide or too high
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
      FORMULA = "if(
        ha > 150 OR
          (dx > dy AND (dx > 27 OR dy > 19)) OR
          (dy > dx AND (dy > 27 OR dx > 19)),
        0, 1
      )", FIELD_TYPE = 1,
      OUTPUT = qgis_tmp_vector()
    ) |>
    # set small polygons aside
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ok",
      OPERATOR = "=", OUTPUT = here(target_folder, "to_refine.gpkg"), VALUE = 0,
      FAIL_OUTPUT = here(target_folder, "open_ruimte_ok_1.gpkg")
    )
  qgis_clean_tmp()
}

# extract the highway, railway and waterway from the OSM data
# we will use them as barriers to split to_refine into smaller polygons
if (!file_test("-f", here(target_folder, "waterway.gpkg"))) {
  download_folder <- here("data", "downloads")
  osm_pbf <- here(download_folder, "geofabrik_belgium-latest.osm.pbf")
  osm_gpkg <- oe_vectortranslate(file_path = osm_pbf, layer = "lines")

  paste0(osm_gpkg, "|layername=lines") |>
    setNames("INPUT") |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway", VALUE = NULL,
      OPERATOR = "is not null", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:retainfields", FIELDS = "highway",
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:reprojectlayer",
      OUTPUT = here(target_folder, "highway.gpkg"),
      TARGET_CRS = paste(
        "PROJ4:+proj=lcc +lat_0=90 +lon_0=4.36748666666667",
        "+lat_1=51.1666672333333 +lat_2=49.8333339 +x_0=150000.013",
        "+y_0=5400088.438 +ellps=intl",
        "+towgs84=-99.059,53.322,-112.486,0.419,-0.83,1.885,-1",
        "+units=m +no_defs"
      )
    )
  paste0(osm_gpkg, "|layername=lines") |>
    setNames("INPUT") |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "waterway", VALUE = NULL,
      OPERATOR = "is not null", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:retainfields", OUTPUT = qgis_tmp_vector(),
      FIELDS = "waterway"
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:reprojectlayer",
      OUTPUT = here(target_folder, "waterway.gpkg"),
      TARGET_CRS = paste(
        "PROJ4:+proj=lcc +lat_0=90 +lon_0=4.36748666666667",
        "+lat_1=51.1666672333333 +lat_2=49.8333339 +x_0=150000.013",
        "+y_0=5400088.438 +ellps=intl",
        "+towgs84=-99.059,53.322,-112.486,0.419,-0.83,1.885,-1",
        "+units=m +no_defs"
      )
    )
  paste0(osm_gpkg, "|layername=lines") |>
    setNames("INPUT") |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "other_tags",
      VALUE = "\"railway\"=>\"rail\"", OPERATOR = 7, OUTPUT = qgis_tmp_vector(),
      FAIL_OUTPUT = NULL
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:reprojectlayer",
      OUTPUT = here(target_folder, "railway.gpkg"),
      TARGET_CRS = paste(
        "PROJ4:+proj=lcc +lat_0=90 +lon_0=4.36748666666667",
        "+lat_1=51.1666672333333 +lat_2=49.8333339 +x_0=150000.013",
        "+y_0=5400088.438 +ellps=intl",
        "+towgs84=-99.059,53.322,-112.486,0.419,-0.83,1.885,-1",
        "+units=m +no_defs"
      )
    )
  qgis_clean_tmp()
}

# select the relevant elements from the highway set
if (!file_test("-f", here(target_folder, "highway_other.gpkg"))) {
  here(target_folder, "highway.gpkg") |>
    setNames("INPUT") |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "residential",
      FAIL_OUTPUT = here(target_folder, "highway_residential.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "unclassified",
      FAIL_OUTPUT = here(target_folder, "highway_unclassified.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "tertiary",
      FAIL_OUTPUT = here(target_folder, "highway_tertiary.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "tertiary_link",
      FAIL_OUTPUT = here(target_folder, "highway_tertiary_link.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "secondary",
      FAIL_OUTPUT = here(target_folder, "highway_secondary.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "secondary_link",
      FAIL_OUTPUT = here(target_folder, "highway_secondary_link.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "track",
      FAIL_OUTPUT = here(target_folder, "highway_track.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(),
      VALUE = "path", FAIL_OUTPUT = here(target_folder, "highway_path.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "motorway",
      FAIL_OUTPUT = here(target_folder, "highway_motorway.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "motorway_link",
      FAIL_OUTPUT = here(target_folder, "highway_motorway_link.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "trunk",
      FAIL_OUTPUT = here(target_folder, "highway_trunk.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "trunk_link",
      FAIL_OUTPUT = here(target_folder, "highway_trunk_link.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "primary",
      FAIL_OUTPUT = here(target_folder, "highway_primary.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "primary_link",
      FAIL_OUTPUT = here(target_folder, "highway_primary_link.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "highway",
      OPERATOR = "≠", OUTPUT = here(target_folder, "highway_other.gpkg"),
      VALUE = "service",
      FAIL_OUTPUT = here(target_folder, "highway_service.gpkg")
    )
  qgis_clean_tmp()
}

# select the relevant items for the waterway set
if (file_test("-f", here(target_folder, "waterway_stream.gpkg"))) {
  here(target_folder, "waterway.gpkg") |>
    setNames("INPUT") |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "waterway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "river",
      FAIL_OUTPUT = here(target_folder, "waterway_river.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "waterway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "canal",
      FAIL_OUTPUT = here(target_folder, "waterway_canal.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "waterway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "stream",
      FAIL_OUTPUT = here(target_folder, "waterway_stream.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "waterway",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "ditch",
      FAIL_OUTPUT = here(target_folder, "waterway_ditch.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "waterway",
      OPERATOR = "≠", OUTPUT = here(target_folder, "waterway_other.gpkg"),
      FAIL_OUTPUT = here(target_folder, "waterway_drain.gpkg"), VALUE = "drain"
    )
  qgis_clean_tmp()
}

# create a buffer around the lines in order to give them a width
if (!file_test("-f", here(target_folder, "buffer_highway_residential.gpkg"))) {
  to_buffer <- list.files(
    target_folder, pattern = "^(high|rail|water)way.*.gpkg", full.names = TRUE
  )
  done <- list.files(
    target_folder, pattern = "^buffer_(high|rail|water)way.*.gpkg",
    full.names = TRUE
  )
  for (i in to_buffer[!to_buffer %in% gsub("buffer_", "", done)]) {
    i |>
      qgis_run_algorithm_p(
        algorithm = "native:buffer", DISTANCE = 5, DISSOLVE = FALSE,
        END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
        OUTPUT = here(target_folder, paste0("buffer_", basename(i)))
      )
    qgis_clean_tmp()
  }
}

# merge all the level 1 barriers into a single layer
if (!file_test("-f", here(target_folder, "main_buffer.gpkg"))) {
  sprintf(
    "%s/buffer_%s.gpkg", target_folder,
    c(
      "railway", "highway_motorway", "highway_motorway_link", "highway_trunk",
      "highway_trunk_link", "waterway_river", "waterway_canal"
    )
  ) |>
    as.list() |>
    do.call(what = "qgis_list_input") |>
    qgis_run_algorithm_p(
      algorithm = "native:mergevectorlayers",
      OUTPUT = here(target_folder, "main_buffer.gpkg"),
      CRS = paste(
        "PROJ4:+proj=lcc +lat_0=90 +lon_0=4.36748666666667",
        "+lat_1=51.1666672333333 +lat_2=49.8333339 +x_0=150000.013",
        "+y_0=5400088.438 +ellps=intl",
        "+towgs84=-99.059,53.322,-112.486,0.419,-0.83,1.885,-1",
        "+units=m +no_defs"
      )
    )
}

# create small polygons and assign the area defined by the barriers at different
# levels
# all polygons with identical value for level X are not separated by a barrier
# of level X of lower.
# E.g. polygons with identical level 2 values, will have identical level 1
# barriers.
if (!file_test("-f", here(target_folder, "open_ruimte_buffer.gpkg"))) {
  here(target_folder, "main_buffer.gpkg") |>
    # buffer to create a single large polygon covering the entire area
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 20000, DISSOLVE = TRUE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector(), SEPARATE_DISJOINT = FALSE
    ) |>
    # split the large polygon by the level 1 barriers
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(),
      OVERLAY = here(target_folder, "main_buffer.gpkg"), GRID = NULL
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:retainfields", OUTPUT = qgis_tmp_vector(),
      FIELDS = "fid"
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:renametablefield", FIELD = "fid", NEW_NAME = "level1",
      OUTPUT = qgis_tmp_vector(),
    ) |>
    # split the level 1 polygons by the level 2 barriers
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(),
      OVERLAY = here(target_folder, "buffer_waterway_stream.gpkg"), GRID = NULL
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(),
      OVERLAY = here(target_folder, "buffer_waterway_drain.gpkg"), GRID = NULL
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(), GRID = NULL,
      OVERLAY = here(target_folder, "..", "open_area", "natural_water.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:retainfields", OUTPUT = qgis_tmp_vector(),
      FIELDS = c("fid", "level1")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:renametablefield", FIELD = "fid", NEW_NAME = "level2",
      OUTPUT = qgis_tmp_vector(),
    ) |>
    # split the level 2 polygons by the level 3 barriers
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(),
      OVERLAY = here(target_folder, "buffer_highway_primary.gpkg"), GRID = NULL
    ) |>
    # buffer with zero distance to fix geometry
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector(), SEPARATE_DISJOINT = FALSE
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(), GRID = NULL,
      OVERLAY = here(target_folder, "buffer_highway_primary_link.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(), GRID = NULL,
      OVERLAY = here(target_folder, "buffer_highway_secondary.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(), GRID = NULL,
      OVERLAY = here(target_folder, "buffer_highway_secondary_link.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    # buffer with zero distance to fix geometry
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector(), SEPARATE_DISJOINT = FALSE
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:retainfields", OUTPUT = qgis_tmp_vector(),
      FIELDS = c("fid", "level1", "level2")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:renametablefield", FIELD = "fid", NEW_NAME = "level3",
      OUTPUT = qgis_tmp_vector(),
    ) |>
    # split the level 3 polygons by the level 4 barriers
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(), GRID = NULL,
      OVERLAY = here(target_folder, "buffer_highway_tertiary.gpkg")
    ) |>
    # buffer with zero distance to fix geometry
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector(), SEPARATE_DISJOINT = FALSE
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(), GRID = NULL,
      OVERLAY = here(target_folder, "buffer_highway_tertiary_link.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:retainfields", OUTPUT = qgis_tmp_vector(),
      FIELDS = c("fid", "level1", "level2", "level3")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:renametablefield", FIELD = "fid", NEW_NAME = "level4",
      OUTPUT = qgis_tmp_vector()
    ) |>
    # split the level 4 polygons by the level 5 barriers
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(), GRID = NULL,
      OVERLAY = here(target_folder, "buffer_highway_residential.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(), GRID = NULL,
      OVERLAY = here(target_folder, "buffer_highway_unclassified.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:retainfields", OUTPUT = qgis_tmp_vector(),
      FIELDS = c("fid", "level1", "level2", "level3", "level4")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:renametablefield", FIELD = "fid", NEW_NAME = "level5",
      OUTPUT = qgis_tmp_vector(),
    ) |>
    # split the level 5 polygons by the level 6 barriers
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(), GRID = NULL,
      OVERLAY = here(target_folder, "buffer_highway_path.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(), GRID = NULL,
      OVERLAY = here(target_folder, "buffer_highway_track.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(), GRID = NULL,
      OVERLAY = here(target_folder, "buffer_highway_service.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(), GRID = NULL,
      OVERLAY = here(target_folder, "buffer_waterway_ditch.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    # buffer with zero distance to fix geometry
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = here(target_folder, "open_ruimte_buffer"),
      SEPARATE_DISJOINT = FALSE
    )
}

# combine the to_refine level with the barrier information
if (!file_test("-f", here(target_folder, "open_ruimte_merge.gpkg"))) {
  here(target_folder, "to_refine.gpkg") |>
    qgis_run_algorithm_p(
      algorithm = "native:intersection", GRID_SIZE = NULL,
      INPUT_FIELDS =  c("fid", "VELDID", "WBENR"), OUTPUT = qgis_tmp_vector(),
      OVERLAY =  here(target_folder, "open_ruimte_buffer.gpkg"),
      OVERLAY_FIELDS = c("level1", "level2", "level3", "level4", "level5"),
      OVERLAY_FIELDS_PREFIX = ""
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    # calculate the area of the polygons
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ha",
      FORMULA = "$area / 10000", FIELD_TYPE = "Decimal (double)", # nolint
      OUTPUT = qgis_tmp_vector()
    ) |>
    # keep only the polygons with a size of at least 0.01 ha
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ha", VALUE = 0.01,
      OPERATOR = "≥", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
    ) |>
    # calculate the bounding boxes of the polygons
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "x_min",
      FORMULA = "x_min($geometry) / 100", FIELD_TYPE = "Decimal (double)", # nolint
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "x_max",
      FORMULA = "x_max($geometry) / 100", FIELD_TYPE = "Decimal (double)", # nolint
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "y_min",
      FORMULA = "y_min($geometry) / 100", FIELD_TYPE = "Decimal (double)", # nolint
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "y_max",
      FORMULA = "y_max($geometry) / 100", FIELD_TYPE = "Decimal (double)", # nolint
      OUTPUT = here(target_folder, "open_ruimte_merge.gpkg")
    )
  qgis_clean_tmp()
}

# glue the small parts back together into larger sampling areas
here(target_folder, "open_ruimte_merge.gpkg") |>
  read_sf() |>
  filter(.data$ha >= 0.01) -> to_merge
list.files(target_folder, pattern = "veld") |>
  str_replace("veld_(.*).gpkg", "\\1") -> done
to_do <- sort(unique(to_merge$VELDID[!to_merge$VELDID %in% done]))
for (current_field in to_do) {
  message(current_field)
  to_merge |>
    filter(.data$VELDID == current_field) -> merge_base
  merge_base |>
    st_drop_geometry() |>
    select(-"WBENR", -"VELDID") |>
    mutate(id = row_number()) -> base_points
  # calculate the distance matrix between polygons
  st_distance(merge_base, merge_base) |>
    `class<-`(class(penalty_matrix)) -> distance_matrix
  # calculate distance penalties
  # two polygons on a different side of a barrier gain a penalty
  # crossing a level 1 barrier results in a very large penalty
  expand_grid(
    from = seq_along(base_points$id), to = seq_along(base_points$id)
  ) |>
    inner_join(base_points, by = c("from" = "id")) |>
    inner_join(base_points, by = c("to" = "id")) |>
    mutate(
      dx = pmax(.data$x_max.x, .data$x_max.y) -
        pmin(.data$x_min.x, .data$x_min.y),
      dy = pmax(.data$y_max.x, .data$y_max.y) -
        pmin(.data$y_min.x, .data$y_min.y)
    ) |>
    transmute(
      .data$from, .data$to,
      distance = 1e6 * (.data$level1.x != .data$level1.y) +
        200 * (.data$level2.x != .data$level2.y) +
        200 * (.data$level3.x != .data$level3.y) +
        200 * (.data$level4.x != .data$level4.y) +
        200 * (.data$level5.x != .data$level5.y)
    ) |>
    pivot_wider(names_from = "to", values_from = "distance") |>
    select(-"from") |>
    as.matrix() -> penalty_matrix
  # calculate the dendrogram based on the penalised distances
  diana(penalty_matrix + distance_matrix, diss = TRUE) |>
    as.dendrogram() -> dendrogram
  # split the dendrogram into the relevant clusters
  clusters <- generate_cluster(dendrogram, base_points)
  # define which polygons belong to which cluster
  lapply(
    seq_along(clusters), clusters,
    FUN = function(i, clusters) {
      data.frame(cluster = i, id = clusters[[i]])
    }
  ) |>
    bind_rows() |>
    arrange(.data$id) -> cluster_order
  # store the cluster information
  bind_cols(merge_base, cluster_order) |>
    group_by(
      .data$WBENR, .data$VELDID,
      id = sprintf(fmt = "%s_%02i", .data$VELDID, .data$cluster)
    ) |>
    summarise(ha = sum(.data$ha), .groups = "drop") |>
    st_make_valid() |>
    st_write(here(target_folder, sprintf("veld_%s.gpkg", current_field)))
}

# merge the sampling areas for the individual hunting grounds into a single
# layer
if (!file_test("-f", here(target_folder, "open_ruimte_ok_2.gpkg"))) {
  # since the number of field is large, we will merge them in two steps
  # first West Flanders and East Flanders
  list.files(
    target_folder, pattern = "^veld_(1|2).*.gpkg$", full.names = TRUE
  ) |>
    as.list() |>
    do.call(what = "qgis_list_input") |>
    qgis_run_algorithm_p(
      algorithm = "native:mergevectorlayers",
      OUTPUT = qgis_tmp_vector(),
      CRS = paste(
        "PROJ4:+proj=lcc +lat_0=90 +lon_0=4.36748666666667",
        "+lat_1=51.1666672333333 +lat_2=49.8333339 +x_0=150000.013",
        "+y_0=5400088.438 +ellps=intl",
        "+towgs84=-99.059,53.322,-112.486,0.419,-0.83,1.885,-1",
        "+units=m +no_defs"
      )
    ) |>
    qgis_extract_output() |>
    # then add Antwerp, Limbourg and Flemish Brabant
    c(list.files(
      target_folder, pattern = "^veld_(3|4|5).*.gpkg$", full.names = TRUE
    )) |>
    as.list() |>
    do.call(what = "qgis_list_input") |>
    qgis_run_algorithm_p(
      algorithm = "native:mergevectorlayers", OUTPUT = qgis_tmp_vector(),
      CRS = paste(
        "PROJ4:+proj=lcc +lat_0=90 +lon_0=4.36748666666667",
        "+lat_1=51.1666672333333 +lat_2=49.8333339 +x_0=150000.013",
        "+y_0=5400088.438 +ellps=intl",
        "+towgs84=-99.059,53.322,-112.486,0.419,-0.83,1.885,-1",
        "+units=m +no_defs"
      )
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:retainfields", OUTPUT = qgis_tmp_vector(),
      FIELDS = c("WBENR", "VELDID", "id")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:dissolve", FIELD = "id", OUTPUT = qgis_tmp_vector(),
      SEPARATE_DISJOINT = FALSE
    ) |>
    # buffer to undo the gaps between the polygons due to the barriers
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 5, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector(), SEPARATE_DISJOINT = FALSE
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:snappointstogrid", OUTPUT = qgis_tmp_vector(),
      HSPACING = 0.5, VSPACING = 0.5, ZSPACING = 0.5, MSPACING = 0.5
    ) |>
    # buffer with zero distance to fix geometry
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = here(target_folder, "veld_tmp_join.gpkg"),
      SEPARATE_DISJOINT = FALSE
    )
  here(target_folder, "to_refine.gpkg") |>
    qgis_run_algorithm_p(
      algorithm = "native:dissolve", SEPARATE_DISJOINT = FALSE,
      OUTPUT = qgis_tmp_vector(), FIELD = NULL
    ) |>
    # clip to to_refine layer to avoid areas outside the hunting grounds
    qgis_run_algorithm_p(
      algorithm = "native:clip", OUTPUT = qgis_tmp_vector(),
      INPUT = here(target_folder, "veld_tmp_join.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    # calculate the area in ha
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ha",
      FORMULA = "$area / 10000"
    ) |>
    # keep only the polygons with a size of at least 0.025 ha
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ha", VALUE = 0.025,
      OPERATOR = ">", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:dissolve", FIELD = "id", SEPARATE_DISJOINT = FALSE,
      OUTPUT = here(target_folder, "open_ruimte_ok_2.gpkg")
    )
  qgis_clean_tmp()
}

if (!file_test("-f", here(target_folder, "telblok.gpkg"))) {
  here(target_folder, "open_ruimte_ok_1.gpkg") |>
    setNames("INPUT") |>
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "id",
      FORMULA = "format('%1_01', \"VELDID\")", FIELD_TYPE = "Text (string)",
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_extract_output() |>
    as.list() |>
    c(here(target_folder, "open_ruimte_ok_2.gpkg")) |>
    do.call(what = "qgis_list_input") |>
    qgis_run_algorithm_p(
      algorithm = "native:mergevectorlayers",
      OUTPUT = qgis_tmp_vector(),
      CRS = paste(
        "PROJ4:+proj=lcc +lat_0=90 +lon_0=4.36748666666667",
        "+lat_1=51.1666672333333 +lat_2=49.8333339 +x_0=150000.013",
        "+y_0=5400088.438 +ellps=intl",
        "+towgs84=-99.059,53.322,-112.486,0.419,-0.83,1.885,-1",
        "+units=m +no_defs"
      )
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:retainfields", OUTPUT = qgis_tmp_vector(),
      FIELDS = c("WBENR", "VELDID", "id")
    ) |>
      # bereken de breedte van de bounding box in hm
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "dx",
      FORMULA = "bounds_width($geometry) / 100",
      FIELD_TYPE = "Decimal (double)", OUTPUT = qgis_tmp_vector()
    ) |>
    # bereken de hoogte van de bounding box in hm
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "dy",
      FORMULA = "bounds_height($geometry) / 100",
      FIELD_TYPE = "Decimal (double)", OUTPUT = qgis_tmp_vector()
    ) |>
    # landscape of portrait
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "landscape",
      FORMULA = '"dx" > "dy"', FIELD_TYPE = "Integer (32 bit)",
      OUTPUT = here(target_folder, "telblok.gpkg")
    )
  qgis_clean_tmp()
}

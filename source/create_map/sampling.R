renv::restore()
library(cluster)
library(deldir)
library(here)
library(osmextract)
library(qgisprocess)
library(sf)
library(tidyverse)
qgis_configure()

target_folder <- here("data", "sampling")
dir.create(target_folder, showWarnings = FALSE)

if (!file_test("-f", here(target_folder, "to_refine.gpkg"))) {
  here("data", "open_area", "open_ruimte.gpkg") |>
    setNames("INPUT") |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "WBENR", VALUE = NULL,
      OPERATOR = "is not null", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:reprojectlayer",
      OUTPUT = here(target_folder, "open_ruimte_lambert75.gpkg"),
      TARGET_CRS = paste(
        "PROJ4:+proj=lcc +lat_0=90 +lon_0=4.36748666666667",
        "+lat_1=51.1666672333333 +lat_2=49.8333339 +x_0=150000.013",
        "+y_0=5400088.438 +ellps=intl",
        "+towgs84=-99.059,53.322,-112.486,0.419,-0.83,1.885,-1",
        "+units=m +no_defs"
      )
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:dissolve", FIELD = "VELDID"
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector()
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
    # bereken de oppervlakte in ha
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

if (!file_test("-f", here(target_folder, "open_ruimte_buffer.gpkg"))) {
  here("data", "open_area", "jacht.gpkg") |>
    setNames("INPUT") |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "WBENR", VALUE = NULL,
      OPERATOR = "is not null", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:reprojectlayer",
      OUTPUT = here(target_folder, "open_ruimte_lambert75.gpkg"),
      TARGET_CRS = paste(
        "PROJ4:+proj=lcc +lat_0=90 +lon_0=4.36748666666667",
        "+lat_1=51.1666672333333 +lat_2=49.8333339 +x_0=150000.013",
        "+y_0=5400088.438 +ellps=intl",
        "+towgs84=-99.059,53.322,-112.486,0.419,-0.83,1.885,-1",
        "+units=m +no_defs"
      )
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(),
      OVERLAY = here(target_folder, "main_buffer.gpkg"), GRID = NULL
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:retainfields", OUTPUT = qgis_tmp_vector(),
      FIELDS = c("fid", "VELDID", "WBENR")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:renametablefield", FIELD = "fid", NEW_NAME = "level1",
      OUTPUT = qgis_tmp_vector(),
    ) |>
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
      FIELDS = c("fid", "VELDID", "WBENR", "level1")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:renametablefield", FIELD = "fid", NEW_NAME = "level2",
      OUTPUT = qgis_tmp_vector(),
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(),
      OVERLAY = here(target_folder, "buffer_highway_primary.gpkg"), GRID = NULL
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector()
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
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:retainfields", OUTPUT = qgis_tmp_vector(),
      FIELDS = c("fid", "VELDID", "WBENR", "level1", "level2")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:renametablefield", FIELD = "fid", NEW_NAME = "level3",
      OUTPUT = qgis_tmp_vector(),
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference", OUTPUT = qgis_tmp_vector(), GRID = NULL,
      OVERLAY = here(target_folder, "buffer_highway_tertiary.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector()
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
      FIELDS = c("fid", "VELDID", "WBENR", "level1", "level2", "level3")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:renametablefield", FIELD = "fid", NEW_NAME = "level4",
      OUTPUT = qgis_tmp_vector(),
    ) |>
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
      FIELDS = c("fid", "VELDID", "WBENR", "level1", "level2", "level3", "level4")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:renametablefield", FIELD = "fid", NEW_NAME = "level5",
      OUTPUT = qgis_tmp_vector(),
    ) |>
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
      algorithm = "native:multiparttosingleparts",
      OUTPUT = here(target_folder, "open_ruimte_buffer")
    )
}

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
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ha",
      FORMULA = "$area / 10000", FIELD_TYPE = "Decimal (double)", # nolint
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ha", VALUE = 0.01,
      OPERATOR = "≥", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
    ) |>
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

get_leafs <- function(object) {
  if (is.leaf(object)) {
    return(as.integer(attributes(object)$label))
  }
  return(c(get_leafs(object[[1]]), get_leafs(object[[2]])))
}

generate_cluster <- function(
  dendrogram, base_points, max_width = 27, max_height = 19, max_ha = 150
) {
  leafs <- get_leafs(dendrogram)
  if (length(leafs) == 1) {
    return(list(leafs))
  }
  base_points |>
    slice(leafs) |>
    summarise(
      ha = sum(.data$ha), x_min = min(.data$x_min), x_max = max(.data$x_max),
      y_min = min(.data$y_min), y_max = max(.data$y_max),
      n_1 = length(unique(.data$level1))
    ) |>
    mutate(
      dx = .data$x_max - .data$x_min, dy = .data$y_max - .data$y_min,
      width = pmax(.data$dx, .data$dy), height = pmin(.data$dx, .data$dy)
    ) -> cluster_summary
  if (
    cluster_summary$width <= max_width &&
    cluster_summary$height <= max_height &&
    cluster_summary$ha <= max_ha && cluster_summary$n_1 == 1
  ) {
    return(list(leafs))
  }
  c(
    generate_cluster(
      dendrogram = dendrogram[[1]], base_points = base_points,
      max_width = max_width, max_height = max_height, max_ha = max_ha
    ),
    generate_cluster(
      dendrogram = dendrogram[[2]], base_points = base_points,
      max_width = max_width, max_height = max_height, max_ha = max_ha
    )
  )
}

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
  st_distance(merge_base, merge_base) |>
    `class<-`(class(penalty_matrix)) -> distance_matrix
  diana(penalty_matrix + distance_matrix, diss = TRUE) |>
    as.dendrogram() -> dendrogram
  clusters <- generate_cluster(dendrogram, base_points)
  lapply(
    seq_along(clusters), clusters,
    FUN = function(i, clusters) {
      data.frame(cluster = i, id = clusters[[i]])
    }
  ) |>
    bind_rows() |>
    arrange(.data$id) -> cluster_order
  bind_cols(merge_base, cluster_order) |>
    group_by(
      .data$WBENR, .data$VELDID,
      id = sprintf(fmt = "%s_%02i", .data$VELDID, .data$cluster)
    ) |>
    summarise(ha = sum(.data$ha), .groups = "drop") |>
    st_make_valid() |>
    st_write(here(target_folder, sprintf("veld_%s.gpkg", current_field)))
}

if (!file_test("-f", here(target_folder, "open_ruimte_ok_2.gpkg"))) {
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
      algorithm = "native:dissolve", FIELD = "id", OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 5, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:snappointstogrid", OUTPUT = qgis_tmp_vector(),
      HSPACING = 0.5, VSPACING = 0.5
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:clip", OUTPUT = qgis_tmp_vector(),
      OVERLAY = here(target_folder, "to_refine.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    # bereken de oppervlakte in ha
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ha",
      FORMULA = "$area / 10000"
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ha", VALUE = 0.025,
      OPERATOR = ">", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:dissolve", FIELD = "id",
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

# sampling by WBENR instead of VELDID

if (!file_test("-f", here(target_folder, "to_refine_wbe.gpkg"))) {
  here(target_folder, "open_ruimte_lambert75.gpkg") |>
    setNames("INPUT") |>
    qgis_run_algorithm_p(
      algorithm = "native:retainfields", FIELDS = "WBENR",
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "WBENR", OPERATOR = 9,
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:dissolve", FIELD = "WBENR"
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector()
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
    # bereken de oppervlakte in ha
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
      OPERATOR = "=", OUTPUT = here(target_folder, "to_refine_wbe.gpkg"), VALUE = 0,
      FAIL_OUTPUT = here(target_folder, "open_ruimte_ok_1_wbe.gpkg")
    )
  qgis_clean_tmp()
}

if (!file_test("-f", here(target_folder, "open_ruimte_klein_10_wbe.gpkg"))) {
  here(target_folder, "open_ruimte_lambert75.gpkg") |>
    qgis_run_algorithm_p(
      algorithm = "native:retainfields", FIELDS = "WBENR",
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "WBENR", OPERATOR = 9,
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:joinattributestable", FIELD = "WBENR",
      OUTPUT = qgis_tmp_vector(),
      INPUT_2 = here(target_folder, "to_refine_wbe.gpkg"),
      FIELD_2 = "WBENR", DISCARD_NONMATCHING = TRUE,
      METHOD =
        "Take attributes of the first matching feature only (one-to-one)",
      FIELDS_TO_COPY = "fid", PREFIX = "junk", NON_MATCHING = NULL
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    # determine which polygons are too large, too wide or too high
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
      FORMULA = "if(
        $area > 500000 OR
          bounds_width($geometry) > 1900 OR
          bounds_height($geometry) > 1900,
        0, 1
      )", FIELD_TYPE = 1,
      OUTPUT = qgis_tmp_vector()
    ) |>
    # set small polygons aside
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ok",
      OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_1_wbe.gpkg")
    ) |>
    # clip large polygons by secondary highways
    qgis_run_algorithm_p(
      algorithm = "native:difference",
      OVERLAY = here(target_folder, "buffer_highway_secondary.gpkg"),
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    # determine which polygons are too large, too wide or too high
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
      FORMULA = "if(
        $area > 500000 OR
          bounds_width($geometry) > 1900 OR
          bounds_height($geometry) > 1900,
        0, 1
      )", FIELD_TYPE = 1,
      OUTPUT = qgis_tmp_vector()
    ) |>
    # set small polygons aside
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ok",
      OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_2_wbe.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference",
      OVERLAY = here(target_folder, "buffer_highway_tertiary.gpkg"),
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    # determine which polygons are too large, too wide or too high
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
      FORMULA = "if(
        $area > 500000 OR
          bounds_width($geometry) > 1900 OR
          bounds_height($geometry) > 1900,
        0, 1
      )", FIELD_TYPE = 1,
      OUTPUT = qgis_tmp_vector()
    ) |>
    # set small polygons aside
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ok",
      OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_3_wbe.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference",
      OVERLAY = here(target_folder, "buffer_waterway_stream.gpkg"),
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    # determine which polygons are too large, too wide or too high
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
      FORMULA = "if(
        $area > 500000 OR
          bounds_width($geometry) > 1900 OR
          bounds_height($geometry) > 1900,
        0, 1
      )", FIELD_TYPE = 1,
      OUTPUT = qgis_tmp_vector()
    ) |>
    # set small polygons aside
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ok",
      OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_4_wbe.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference",
      OVERLAY = here(target_folder, "buffer_highway_unclassified.gpkg"),
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    # determine which polygons are too large, too wide or too high
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
      FORMULA = "if(
        $area > 500000 OR
          bounds_width($geometry) > 1900 OR
          bounds_height($geometry) > 1900,
        0, 1
      )", FIELD_TYPE = 1,
      OUTPUT = qgis_tmp_vector()
    ) |>
    # set small polygons aside
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ok",
      OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_5_wbe.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference",
      OVERLAY = here(target_folder, "buffer_highway_track.gpkg"),
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    # determine which polygons are too large, too wide or too high
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
      FORMULA = "if(
        $area > 500000 OR
          bounds_width($geometry) > 1900 OR
          bounds_height($geometry) > 1900,
        0, 1
      )", FIELD_TYPE = 1,
      OUTPUT = qgis_tmp_vector()
    ) |>
    # set small polygons aside
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ok",
      OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_6_wbe.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference",
      OVERLAY = here(target_folder, "buffer_waterway_ditch.gpkg"),
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    # determine which polygons are too large, too wide or too high
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
      FORMULA = "if(
        $area > 500000 OR
          bounds_width($geometry) > 1900 OR
          bounds_height($geometry) > 1900,
        0, 1
      )", FIELD_TYPE = 1,
      OUTPUT = qgis_tmp_vector()
    ) |>
    # set small polygons aside
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ok",
      OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_7_wbe.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference",
      OVERLAY = here(target_folder, "buffer_waterway_drain.gpkg"),
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    # determine which polygons are too large, too wide or too high
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
      FORMULA = "if(
        $area > 500000 OR
          bounds_width($geometry) > 1900 OR
          bounds_height($geometry) > 1900,
        0, 1
      )", FIELD_TYPE = 1,
      OUTPUT = qgis_tmp_vector()
    ) |>
    # set small polygons aside
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ok",
      OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_8_wbe.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference",
      OVERLAY = here(target_folder, "buffer_highway_path.gpkg"),
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    # determine which polygons are too large, too wide or too high
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
      FORMULA = "if(
        $area > 500000 OR
          bounds_width($geometry) > 1900 OR
          bounds_height($geometry) > 1900,
        0, 1
      )", FIELD_TYPE = 1,
      OUTPUT = qgis_tmp_vector()
    ) |>
    # set small polygons aside
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ok",
      OPERATOR = "=", OUTPUT = qgis_tmp_vector(), VALUE = 0,
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_9_wbe.gpkg")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:difference",
      OVERLAY = here(target_folder, "buffer_highway_service.gpkg"),
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:multiparttosingleparts", OUTPUT = qgis_tmp_vector()
    ) |>
    # determine which polygons are too large, too wide or too high
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ok",
      FORMULA = "if(
        $area > 500000 OR
          bounds_width($geometry) > 1900 OR
          bounds_height($geometry) > 1900,
        0, 1
      )", FIELD_TYPE = 1,
      OUTPUT = qgis_tmp_vector()
    ) |>
    # set small polygons aside
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ok",
      OPERATOR = "=",  VALUE = 0,
      OUTPUT = here(target_folder, "open_ruimte_klein_rest_wbe.gpkg"),
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_10_wbe.gpkg")
    )
  qgis_clean_tmp()
}

if (!file_test("-f", here(target_folder, "open_ruimte_merge_wbe.gpkg"))) {
  list.files(
    target_folder, pattern = "open_ruimte_klein_.*_wbe", full.names = TRUE
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
    qgis_run_algorithm_p(
      algorithm = "native:retainfields", OUTPUT = qgis_tmp_vector(),
      FIELDS = "WBENR"
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ha",
      FORMULA = "$area / 10000", FIELD_TYPE = "Decimal (double)", # nolint
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "ha", VALUE = 0.01,
      OPERATOR = "≥", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
    ) |>
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
      OUTPUT = here(target_folder, "open_ruimte_merge_wbe.gpkg")
    )
  qgis_clean_tmp()
}

here(target_folder, "open_ruimte_merge_wbe.gpkg") |>
  read_sf() |>
  filter(.data$ha >= 0.01) -> to_merge
list.files(target_folder, pattern = "^wbe") |>
  str_replace("wbe_(.*).gpkg", "\\1") -> done
to_do <- sort(unique(to_merge$WBENR[!to_merge$WBENR %in% done]))
for (current_field in to_do) {
  message(current_field)
  to_merge |>
    filter(.data$WBENR == current_field) -> merge_base
  merge_base |>
    st_drop_geometry() |>
    select(-"WBENR") |>
    mutate(
      grouping = row_number(),
      dx = .data$x_max - .data$x_min,
      dy = .data$y_max - .data$y_min
    ) -> base_points
  merge_base |>
    st_centroid() |>
    st_coordinates() |>
    deldir() %>%
    `[[`("delsgs") %>%
    transmute(
      from = pmin(.data$ind1, .data$ind2), to = pmax(.data$ind1, .data$ind2),
      distance = sqrt((.data$x1 - .data$x2) ^ 2 + (.data$y1 - .data$y2) ^ 2)
    ) |>
    filter(.data$distance < 1000) |>
    select(-"distance") |>
    arrange(.data$from, .data$to) -> connections
  base_points |>
    filter(
      .data$ha > 150 | pmin(.data$dx, .data$dy) > 19 |
        pmax(.data$dx, .data$dy) > 25
    ) |>
    pull(.data$grouping) -> too_large
  connections |>
    filter(!.data$from %in% too_large, !.data$to %in% too_large) -> connections
  while (nrow(connections) > 0) {
    base_points |>
      filter(.data$grouping %in% c(connections$from, connections$to)) |>
      group_by(.data$grouping) |>
      summarise(ha = sum(.data$ha)) |>
      slice_min(.data$ha, n = 1) |>
      pull(.data$grouping) -> smallest
    connections |>
      filter(.data$from == smallest) |>
      select(candidate = "to") |>
      bind_rows(
        connections |>
          filter(.data$to == smallest) |>
          select(candidate = "from")
      ) |>
      pull(.data$candidate) -> candidate
    base_points |>
      filter(.data$grouping == smallest) -> current_small
    penalties <- sapply(
      candidate,
      function(cand, bp = base_points) {
        bp |>
          filter(.data$grouping == cand) |>
          bind_rows(current_small) |>
          get_penalty()
      }
    )
    if (any(is.finite(penalties))) {
      best <- candidate[which.min(penalties)]
      if (best < smallest) {
        base_points$grouping[base_points$grouping == smallest] <- best
        connections$from[connections$from == smallest] <- best
        connections$to[connections$to == smallest] <- best
      } else {
        base_points$grouping[base_points$grouping == best] <- smallest
        connections$from[connections$from == best] <- smallest
        connections$to[connections$to == best] <- smallest
      }
      connections |>
        distinct() |>
        filter(.data$from < .data$to) -> connections
    }
    if (any(is.infinite(penalties))) {
      connections |>
        filter(
          !.data$from %in% candidate[is.infinite(penalties)] |
            .data$to != smallest,
          !.data$to %in% candidate[is.infinite(penalties)] |
            .data$from != smallest
        ) -> connections
    }
  }
  merge_base |>
    transmute(
      .data$WBENR,
      id = base_points$grouping |>
        factor() |>
        as.integer() |>
        sprintf(fmt = "%2$s_%1$02i", .data$WBENR)
    ) |>
    st_make_valid() |>
    st_write(here(target_folder, sprintf("wbe_%s.gpkg", current_field)))
}

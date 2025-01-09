renv::restore()
library(here)
library(tidyverse)
library(sf)
library(deldir)
library(osmextract)
library(qgisprocess)
qgis_configure()

target_folder <- here("data", "sampling")
dir.create(target_folder, showWarnings = FALSE)

if (!file_test("-f", here(target_folder, "to_refine.gpkg"))) {
  here("data", "open_area", "open_ruimte.gpkg") |>
    setNames("INPUT") |>
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
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), VALUE = "secondary",
      FAIL_OUTPUT = here(target_folder, "highway_secondary.gpkg")
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
      OPERATOR = "≠", OUTPUT = here(target_folder, "highway_other.gpkg"),
      VALUE = "service", FAIL_OUTPUT = here(target_folder, "highway_service.gpkg")
    )
  qgis_clean_tmp()
}

if (file_test("-f", here(target_folder, "waterway_stream.gpkg"))) {
  here(target_folder, "waterway.gpkg") |>
    setNames("INPUT") |>
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
    target_folder, pattern = "^(high|water)way.*.gpkg", full.names = TRUE
  )
  for (i in to_buffer) {
    i |>
      qgis_run_algorithm_p(
        algorithm = "native:buffer", DISTANCE = 5, DISSOLVE = FALSE,
        END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
        OUTPUT = here(target_folder, paste0("buffer_", basename(i)))
      )
    qgis_clean_tmp()
  }
}

if (!file_test("-f", here(target_folder, "open_ruimte_klein_1.gpkg"))) {
  here(target_folder, "open_ruimte_lambert75.gpkg") |>
    qgis_run_algorithm_p(
      algorithm = "native:joinattributestable", FIELD = "VELDID",
      OUTPUT = qgis_tmp_vector(), INPUT_2 = here(target_folder, "to_refine.gpkg"),
      FIELD_2 = "VELDID", DISCARD_NONMATCHING = TRUE,
      METHOD = "Take attributes of the first matching feature only (one-to-one)",
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
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_1.gpkg")
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
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_2.gpkg")
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
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_3.gpkg")
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
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_4.gpkg")
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
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_5.gpkg")
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
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_6.gpkg")
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
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_7.gpkg")
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
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_8.gpkg")
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
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_9.gpkg")
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
      OUTPUT = here(target_folder, "open_ruimte_klein_rest.gpkg"),
      FAIL_OUTPUT = here(target_folder, "open_ruimte_klein_10.gpkg")
    )
  qgis_clean_tmp()
}

if (!file_test("-f", here(target_folder, "open_ruimte_merge.gpkg"))) {
  list.files(target_folder, pattern = "open_ruimte_klein", full.names = TRUE) |>
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
      FIELDS = c("VELDID", "WBENR")
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

get_penalty <- function(bp) {
  bp <- data.frame(
    ha = sum(bp$ha), x_min = min(bp$x_min), x_max = min(bp$x_max),
    y_min = min(bp$y_min), y_max = min(bp$y_max)
  )
  bp$dx <- bp$x_max - bp$x_min
  bp$dy <- bp$y_max - bp$y_min
  bp$penalty <- ifelse(
    pmax(bp$dx, bp$dy) > 25, Inf, pmax(bp$dx, bp$dy) / 25
  ) +
    ifelse(
      pmin(bp$dx, bp$dy) > 19, Inf, pmin(bp$dx, bp$dy) / 19
    ) +
    ifelse(bp$ha > 150, Inf, bp$ha / 150)
  sum(bp$penalty)
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
    select(-"VELDID", -"WBENR") |>
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
      .data$WBENR, .data$VELDID,
      id = base_points$grouping |>
        factor() |>
        as.integer() |>
        sprintf(fmt = "%2$s_%1$02i", .data$VELDID)
    ) |>
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
      algorithm = "native:mergevectorlayers",
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
      HSPACING = 1, VSPACING = 1
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


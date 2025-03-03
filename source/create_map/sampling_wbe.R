renv::restore()
library(cluster)
library(here)
library(qgisprocess)
library(sf)
library(tidyverse)
qgis_configure()
source("source/create_map/functions.R")

target_folder <- here("data", "sampling")
dir.create(target_folder, showWarnings = FALSE)

if (!file_test("-f", here(target_folder, "to_refine_wbe.gpkg"))) {
  here(target_folder, "open_ruimte_lambert75.gpkg") |>
    setNames("INPUT") |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "WBENR", VALUE = NULL,
      OPERATOR = "is not null", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:extractbyattribute", FIELD = "WBENR", VALUE = " ",
      OPERATOR = "≠", OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = NULL
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:retainfields", FIELDS = "WBENR",
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
      OPERATOR = "=", OUTPUT = here(target_folder, "to_refine_wbe.gpkg"),
      VALUE = 0, FAIL_OUTPUT = here(target_folder, "open_ruimte_ok_1_wbe.gpkg")
    )
  qgis_clean_tmp()
}

if (!file_test("-f", here(target_folder, "open_ruimte_merge_wbe.gpkg"))) {
  here(target_folder, "to_refine_wbe.gpkg") |>
    qgis_run_algorithm_p(
      algorithm = "native:intersection", GRID_SIZE = NULL,
      INPUT_FIELDS =  c("fid", "WBENR"), OUTPUT = qgis_tmp_vector(),
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
      .data$WBENR, id = sprintf(fmt = "%s_%02i", .data$WBENR, .data$cluster)
    ) |>
    summarise(ha = sum(.data$ha), .groups = "drop") |>
    st_make_valid() |>
    st_write(
      here(target_folder, sprintf("wbe_%s.gpkg", current_field)), quiet = TRUE
    )
}

# merge the sampling areas for the individual hunting grounds into a single
# layer
if (!file_test("-f", here(target_folder, "open_ruimte_ok_2_wbe.gpkg"))) {
  # join all GMU
  list.files(
    target_folder, pattern = "^wbe_[0-9]+.gpkg$", full.names = TRUE
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
      FIELDS = c("WBENR", "id")
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:dissolve", FIELD = "id", OUTPUT = qgis_tmp_vector()
    ) |>
    # buffer to undo the gaps between the polygons due to the barriers
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 5, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector(), SEPARATE_DISJOINT = FALSE
    ) |>
    qgis_run_algorithm_p(
      algorithm = "native:snappointstogrid", OUTPUT = qgis_tmp_vector(),
      HSPACING = 0.5, VSPACING = 0.5
    ) |>
    # buffer with zero distance to fix geometry
    qgis_run_algorithm_p(
      algorithm = "native:buffer", DISTANCE = 0, DISSOLVE = FALSE,
      END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5,
      OUTPUT = here(target_folder, "wbe_tmp_join.gpkg"),
      SEPARATE_DISJOINT = FALSE
    )
  here(target_folder, "to_refine_wbe.gpkg") |>
    qgis_run_algorithm_p(
      algorithm = "native:dissolve", SEPARATE_DISJOINT = FALSE,
      OUTPUT = qgis_tmp_vector(), FIELD = NULL
    ) |>
    # clip to to_refine layer to avoid areas outside the hunting grounds
    qgis_run_algorithm_p(
      algorithm = "native:clip", OUTPUT = qgis_tmp_vector(),
      INPUT = here(target_folder, "wbe_tmp_join.gpkg")
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
      algorithm = "native:dissolve", FIELD = "id",
      OUTPUT = here(target_folder, "open_ruimte_ok_2_wbe.gpkg")
    )
  qgis_clean_tmp()
}

if (!file_test("-f", here(target_folder, "telblok_wbe.gpkg"))) {
  here(target_folder, "open_ruimte_ok_1_wbe.gpkg") |>
    setNames("INPUT") |>
    qgis_run_algorithm_p(
      algorithm = "native:fieldcalculator", FIELD_NAME = "id",
      FORMULA = "format('%1_01', \"WBENR\")", FIELD_TYPE = "Text (string)",
      OUTPUT = qgis_tmp_vector()
    ) |>
    qgis_extract_output() |>
    as.list() |>
    c(here(target_folder, "open_ruimte_ok_2_wbe.gpkg")) |>
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
      FIELDS = c("WBENR", "id")
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
      OUTPUT = here(target_folder, "telblok_wbe.gpkg")
    )
  qgis_clean_tmp()
}

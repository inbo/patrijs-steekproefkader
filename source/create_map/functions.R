get_leafs <- function(object) {
  if (is.leaf(object)) {
    return(as.integer(attributes(object)$label))
  }
  return(c(get_leafs(object[[1]]), get_leafs(object[[2]])))
}

generate_cluster <- function(
  dendrogram, base_points, max_width = 27, max_height = 19, max_ha = 150
) {
  stopifnot(require("dplyr", quietly = TRUE), require("rlang", quietly = TRUE))
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

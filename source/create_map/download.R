renv::restore()
library(here)
library(zen4R)
library(openssl)
library(git2rdata)
library(tidyverse)

options(timeout = max(1000, getOption("timeout")))

dl <- here("data", "downloads")
dir.create(dl, showWarnings = FALSE)

# jachtterreinen
target <- "jacht.gpkg"
if (file_test("-f", here(dl, target))) {
  hashes <- read_vc("checksum", dl)
  map(here(dl, target), file) |>
    map(sha512) |>
    map_chr(as.character) -> hash
  data.frame(file = target, check = hash) |>
    inner_join(hashes, by = "file") -> to_test
  stopifnot(
    "Hash mismatch" = nrow(to_test) == length(target),
    "Hash of downloaded file doesn't match the stored hash" =
      all(to_test$check == to_test$sha512)
  )
} else {
  if (!file_test("-f", here(dl, tolower(target)))) {
    download_zenodo(doi = "10.5281/zenodo.14651015", path = dl, timeout = 600)
  }
  here(dl, target) |>
    file() |>
    sha512() |>
    as.character() |>
    unclass() -> hash

  if (file_test("-f", here(dl, "checksum.csv"))) {
    hashes <- read_vc("checksum", dl)
    stopifnot(
      "Hash of downloaded file doesn't match the stored hash" =
        unclass(as.character(hash)) == hashes$sha512[hashes$file == target]
    )
  } else {
    write_vc(
      data.frame(file = target, sha512 = unclass(as.character(hash))),
      "checksum", root = dl, sorting = "file", optimize = FALSE
    )
    hashes <- read_vc("checksum", dl)
  }
}

# OpenStreetMap
target <- "geofabrik_belgium-latest.osm.pbf"
hashes <- read_vc("checksum", dl)
if (file_test("-f", here(dl, target))) {
  here(dl, target) |>
    file() |>
    sha512() |>
    as.character() |>
    unclass() -> hash
  stopifnot(
    "Hash of downloaded file doesn't match the stored hash" =
      hash == hashes$sha512[hashes$file == target]
  )
} else {
  download_zenodo(doi = "10.5281/zenodo.14139313", path = dl, timeout = 600)
  here(dl, target) |>
    file() |>
    sha512() |>
    as.character() |>
    unclass() -> hash
  if (any(hashes$file == target)) {
    stopifnot(
      "Hash of downloaded file doesn't match the stored hash" =
        hash == hashes$sha512[hashes$file == target]
    )
  } else {
    data.frame(file = target, sha512 = unclass(as.character(hash))) |>
      rbind(hashes) |>
      write_vc(
        "checksum", root = dl, sorting = "file", optimize = FALSE
      )
  }
}

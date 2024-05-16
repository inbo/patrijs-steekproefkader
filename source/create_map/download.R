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
if (file_test("-f", here(dl, "jachtter.shp"))) {
  relevant <- paste0("jachtter", c(".dbf", ".prj", ".shp", ".shx"))
  hashes <- read_vc("checksum", dl)
  map(here(dl, relevant), file) |>
    map(sha512) |>
    map_chr(as.character) -> hash
  data.frame(file = relevant, check = hash) |>
    inner_join(hashes, by = "file") -> to_test
  stopifnot(
    "Hash mismatch" = nrow(to_test) == length(relevant),
    "Hash of downloaded file doesn't match the stored hash" =
      all(to_test$check == to_test$sha512)
  )
} else {
  target <- "jacht.zip"
  if (!file_test("-f", here(dl, target))) {
    download_zenodo(doi = "10.5281/zenodo.10212759", path = dl, timeout = 600)
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
  relevant <- paste0("Jachtter", c(".dbf", ".prj", ".shp", ".shx"))
  unzip(
    zipfile = here(dl, target), overwrite = FALSE, junkpaths = TRUE,
    files = file.path("Shapefile", relevant), setTimes = TRUE, exdir = dl
  )
  file.rename(here(dl, relevant), here(dl, tolower(relevant)))
  map(here(dl, tolower(relevant)), file) |>
    map(sha512) |>
    map_chr(as.character) -> hash
  data.frame(file = tolower(relevant), check = hash) |>
    inner_join(hashes, by = "file") -> to_test
  stopifnot(
    "Hash of downloaded file doesn't match the stored hash" = all(
      "Hash of downloaded file doesn't match the stored hash" =
        all(to_test$check == to_test$sha512)
    )
  )
  data.frame(file = tolower(relevant), sha512 = hash) |>
    anti_join(hashes, by = "file") |>
    bind_rows(hashes) |>
    write_vc("checksum", root = dl, optimize = FALSE)
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
  download_zenodo(doi = "10.5281/zenodo.10212939", path = dl, timeout = 600)
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
    write_vc(
      rbind(
        data.frame(file = target, sha512 = unclass(as.character(hash))), hashes
      ),
      "checksum", root = dl, sorting = "file", optimize = FALSE
    )
  }
}

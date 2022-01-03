renv::restore()
library(here)
library(zen4R)
library(openssl)
library(git2rdata)
library(tidyverse)

options(timeout = max(1000, getOption("timeout")))

dl <- here("downloads")
dir.create(dl, showWarnings = FALSE)

# jachtterreinen
if (!file_test("-f", here(dl, "jachtter.shp"))) {
  target <- "jacht.zip"
  if (!file_test("-f", here(dl, target))) {
    download_zenodo(
      doi = paste("10.5281", "zenodo.5792818", sep = "/"), path = dl
    )
  }
  hash <- sha512(file(here(dl, target)))
  if (file_test("-f", here(dl, "checksum.tsv"))) {
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
  }
  relevant <- paste0("Jachtter", c(".dbf", ".prj", ".shp", ".shx"))
  unzip(
    zipfile = here(dl, target), overwrite = FALSE, junkpaths = TRUE,
    files = file.path("Shapefile", relevant), setTimes = TRUE, exdir = dl
  )
  file.rename(here(dl, relevant), here(dl, tolower(relevant)))
}

# OpenStreetMap
if (!file_test("-f", here(dl, "geofabrik_belgium-latest.osm.pbf"))) {
  target <- "geofabrik_belgium-latest.osm.pbf"
  if (!file_test("-f", here(dl, target))) {
    download_zenodo(
      doi = paste("10.5281", "zenodo.5792949", sep = "/"), path = dl
    )
  }
  hash <- sha512(file(here(dl, target)))
  hashes <- read_vc("checksum", dl)
  if (any(hashes$file == target)) {
    stopifnot(
      "Hash of downloaded file doesn't match the stored hash" =
        unclass(as.character(hash)) == hashes$sha512[hashes$file == target]
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

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
    download_zenodo(doi = "10.5281/zenodo.5792818", path = dl)
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

# biologische waarderingskaart
if (!file_test("-f", here(dl, "bwkhab.shp"))) {
  target <- "bwk.zip"
  if (!file_test("-f", here(dl, target))) {
    download_zenodo(doi = "10.5281/zenodo.5583440", path = dl)
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
  relevant <- paste0("BwkHab", c(".dbf", ".prj", ".shp", ".shx"))
  unzip(
    zipfile = here(dl, target), overwrite = FALSE, junkpaths = TRUE,
    files = file.path("Shapefile", relevant), setTimes = TRUE, exdir = dl
  )
  file.rename(here(dl, relevant), here(dl, tolower(relevant)))
}

# Vlaanderen
if (!file_test("-f", here(dl, "refgew.shp"))) {
  target <- "gemeente.zip"
  if (!file_test("-f", here(dl, target))) {
    download_zenodo(doi = "10.5281/zenodo.5584281", path = dl)
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
  bestanden <- unzip(here(dl, "gemeente.zip"), list = TRUE)
  zippath <- unique(
    dirname(bestanden$Name[grep("Refgew\\.shp", bestanden$Name)])
  )
  relevant <- paste0("Refgew", c(".dbf", ".prj", ".shp", ".shx"))
  unzip(
    zipfile = here(dl, target), overwrite = FALSE, junkpaths = TRUE,
    files = file.path(zippath, relevant), setTimes = TRUE, exdir = dl
  )
  file.rename(here(dl, relevant), here(dl, tolower(relevant)))
}

# Vlaamse hydrografische atlas
if (!file_test("-f", here(dl, "wlas.shp"))) {
  target <- "waterlopen.zip"
  if (!file_test("-f", here(dl, target))) {
    download_zenodo(doi = "10.5281/zenodo.5584530", path = dl)
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
  relevant <- paste0("Wlas", c(".dbf", ".prj", ".shp", ".shx"))
  unzip(
    zipfile = here(dl, target), overwrite = FALSE, junkpaths = TRUE,
    files = file.path("Shapefile", relevant), setTimes = TRUE, exdir = dl
  )
  file.rename(here(dl, relevant), here(dl, tolower(relevant)))
}

# Wegenregister
if (!file_test("-f", here(dl, "refgew.shp"))) {
  target <- "wegenregister.zip"
  if (!file_test("-f", here(dl, target))) {
    download_zenodo(doi = "10.5281/zenodo.5584542", path = dl)
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
  bestanden <- unzip(here(dl, "wegenregister.zip"), list = TRUE)
  zippath <- unique(
    dirname(bestanden$Name[grep("Wegsegment\\.shp", bestanden$Name)])
  )
  relevant <- paste0("Wegsegment", c(".dbf", ".prj", ".shp", ".shx"))
  unzip(
    zipfile = here(dl, target), overwrite = FALSE, junkpaths = TRUE,
    files = file.path(zippath, relevant), setTimes = TRUE, exdir = dl
  )
  file.rename(here(dl, relevant), here(dl, tolower(relevant)))
}

# spoorwegen
if (!file_test("-f", here(dl, "spoorweg.shp"))) {
  download_zenodo(doi = "10.5281/zenodo.5584573", path = dl)
  relevant <- paste0("spoorweg", c(".dbf", ".prj", ".shp", ".shx"))
  hash <- lapply(
    here(dl, relevant),
    function(x) {
      sha512(file(x))
    }
  )
  names(hash) <- relevant
  hashes <- read_vc("checksum", dl)
  for (i in seq_along(hash)) {
    if (any(hashes$file == names(hash)[i])) {
      stopifnot(
        "Hash of downloaded file doesn't match the stored hash" =
          unclass(as.character(hash[[i]])) ==
          hashes$sha512[hashes$file == names(hash)[i]]
      )
    } else {
      hashes <- rbind(
        data.frame(
          file = names(hash)[i], sha512 = unclass(as.character(hash[[i]]))
        ), hashes
      )
      write_vc(
        hashes, "checksum", root = dl, sorting = "file", optimize = FALSE
      )
    }
  }
}

library(here)
library(openssl)
library(git2rdata)
library(osmdata)
library(tidyverse)
library(sf)

options(timeout = max(1000, getOption("timeout")))

dl <- here("downloads")
dir.create(dl, showWarnings = FALSE)

# jachtterreinen
if (!file_test("-f", here(dl, "jachtter.shp"))) {
  target <- "jacht.zip"
  if (!file_test("-f", here(dl, target))) {
    geopunt <- file.path(
      "https://downloadagiv.blob.core.windows.net", "jacht", "jachtterr",
      "2021-2022", "Jacht_2021-2022-01_GewVLA_Shapefile.zip",
      fsep = "/"
    )
    download.file(url = geopunt, here(dl, target))
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
    geopunt <- file.path(
      "https://downloadagiv.blob.core.windows.net", "bwk2", "2020",
      "BWK_en_Natura2000Habitatkaart_2020_GewVLA_Shapefile.zip",
      fsep = "/"
    )
    download.file(url = geopunt, here(dl, target))
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
    geopunt <- file.path(
      "https://downloadagiv.blob.core.windows.net",
      "referentiebestand-gemeenten",
      "VoorlopigRefBestandGemeentegrenzen_2019-01-01",
      "VRBG_toestand_16_05_2018_(geldend_vanaf_01_01_2019)_GewVLA_Shape.zip",
      fsep = "/"
    )
    download.file(url = geopunt, here(dl, target))
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
    geopunt <- file.path(
      "https://downloadagiv.blob.core.windows.net",
      "vlaamse-hydrografische-atlas-waterlopen", "2021",
      "VHA-waterlopen,%202021-08-28",
      "VHA_waterlopen_20210828_GewVLA_Shapefile.zip",
      fsep = "/"
    )
    download.file(url = geopunt, here(dl, target))
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
    geopunt <- file.path(
      "https://downloadagiv.blob.core.windows.net", "wegenregister",
      "Wegenregister_SHAPE_20210916.zip",
      fsep = "/"
    )
    download.file(url = geopunt, here(dl, target))
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

here(dl, "refgew.shp") %>%
  read_sf() %>%
  st_transform(crs = 4326) %>%
  st_bbox() -> vlaanderen_bbox

overpass_url <- "https://lz4.overpass-api.de/api/interpreter"
set_overpass_url(overpass_url[1])
qq <- opq(bbox = unname(vlaanderen_bbox), timeout = getOption("timeout"))

if (!file_test("-f", here(dl, "spoorweg.shp"))) {
  qq %>%
    add_osm_feature(key = "railway", value = "rail") %>%
    osmdata_sf() %>%
    `[[`("osm_lines") %>%
    st_transform(crs = 31370) %>%
    st_buffer(10) %>%
    select(.data$osm_id) %>%
    st_union() %>%
    st_write(here(dl, "spoorweg.shp"))
}

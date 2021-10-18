library(openssl)
library(git2rdata)
dir.create("downloads", showWarnings = FALSE)

# jachtterreinen
target <- "jacht.zip"
if (!file_test("-f", file.path("downloads", target))) {
  geopunt <- file.path(
    "https://downloadagiv.blob.core.windows.net", "jacht", "jachtterr",
    "2021-2022", "Jacht_2021-2022-01_GewVLA_Shapefile.zip",
    fsep = "/"
  )
  download.file(url = geopunt, file.path("downloads", target))
}
hash <- sha512(file(file.path("downloads", target)))
if (file_test("-f", file.path("downloads", "checksum.tsv"))) {
  hashes <- read_vc(file.path("downloads", "checksum"))
  stopifnot(
    "Hash of downloaded file doesn't match the stored hash" =
      unclass(as.character(hash)) == hashes$sha512[hashes$file == target]
  )
} else {
  write_vc(
    data.frame(file = target, sha512 = unclass(as.character(hash))),
    file.path("downloads", "checksum"), sorting = "file", optimize = FALSE
  )
}
relevant <- paste0("Jachtter", c(".dbf", ".prj", ".shp", ".shx"))
unzip(
  zipfile = file.path("downloads", target), overwrite = FALSE, junkpaths = TRUE,
  files = file.path("Shapefile", relevant), setTimes = TRUE, exdir = "downloads"
)
file.rename(
  file.path("downloads", relevant), file.path("downloads", tolower(relevant))
)

# biologische waarderingskaart
target <- "bwk.zip"
if (!file_test("-f", file.path("downloads", target))) {
  geopunt <- file.path(
    "https://downloadagiv.blob.core.windows.net", "bwk2", "2020",
    "BWK_en_Natura2000Habitatkaart_2020_GewVLA_Shapefile.zip",
    fsep = "/"
  )
  download.file(url = geopunt, file.path("downloads", target))
}
hash <- sha512(file(file.path("downloads", target)))
hashes <- read_vc(file.path("downloads", "checksum"))
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
    file.path("downloads", "checksum"), sorting = "file", optimize = FALSE
  )
}
relevant <- paste0("BwkHab", c(".dbf", ".prj", ".shp", ".shx"))
unzip(
  zipfile = file.path("downloads", target), overwrite = FALSE, junkpaths = TRUE,
  files = file.path("Shapefile", relevant), setTimes = TRUE, exdir = "downloads"
)
file.rename(
  file.path("downloads", relevant), file.path("downloads", tolower(relevant))
)

library(keyring)
library(zen4R)
library(osmextract)

osm_source <- oe_match("Belgium")
osm_pbf <- oe_download(
  file_url = osm_source$url, file_size = osm_source$file_size
)

zenodo <- ZenodoManager$new(token = key_get("zenodo"))

myrec <- ZenodoRecord$new()
myrec$setTitle("OpenStreetMap Data Extracts for Belgium")
myrec$setDescription(
  paste(
    "Geofabrik provides data extracts from the OpenStreetMap project.",
    "This is a copy of the data from",
    "https://download.geofabrik.de/europe/belgium.html."
  )
)
myrec$setUploadType("dataset")
myrec$addCreator(lastname = "OpenStreetMap Contributors", firstname = "")
myrec$addCreator(lastname = "Geofabrik", firstname = "")
myrec$setLicense("ODbL-1.0")
myrec$setAccessRight("open")
myrec$setPublicationDate(as.Date("2021-12-20"))
myrec$addRelatedIdentifier(
  "isCompiledBy", "https://download.geofabrik.de/europe/belgium.html"
)
myrec <- zenodo$depositRecord(myrec)
undebug(zenodo$uploadFile)
zenodo$uploadFile(osm_pbf, myrec)

myrec <- zenodo$depositRecord(myrec, publish = TRUE)

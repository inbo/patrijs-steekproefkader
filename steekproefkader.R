library(here)
library(git2rdata)
library(sf)
library(tidyverse)
library(qgisprocess)
qgis_configure()

target_folder <- here("steekproef")
bwk <- here("downloads", "bwkhab.shp")
jachtgebieden <- here("downloads", "jachtter.shp")
vlaanderen <- here("downloads", "refgew.shp")
wegen <- here("downloads", "wegsegment.shp")
waterlopen <- here("downloads", "wlas.shp")
spoorwegen <- here("downloads", "spoorweg.shp")
extra_grenzen <- here("downloads", "extra.shp")

if (!file.exists(here(target_folder, "open_ruimte.gpkg"))) {
  read_vc("bwk_eenheid", root = here("downloads")) %>%
    filter(.data$open) %>%
    pull(.data$eenheid) -> open_eenheden
  qgis_run_algorithm(
    "native:extractbyexpression",
    INPUT = bwk,
    EXPRESSION = paste(
      sprintf("EENH1 = '%s'", open_eenheden),
      collapse = " OR "
    )
  ) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "open", FORMULA = "1"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(algorithm = "native:dissolve", FIELD = "open")) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(algorithm = "native:multiparttosingleparts")) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "open",
        FORMULA = "@row_number"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:buffer", DISTANCE = -0.1, DISSOLVE = FALSE,
        END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    unclass() %>%
    read_sf() %>%
    st_transform(crs = 31370) %>%
    st_write(
      dsn = here(target_folder, "open_ruimte.gpkg"),
      delete_dsn = file.exists(
        here(target_folder, "open_ruimte.gpkg")
      )
    )
}

if (!file.exists(here(target_folder, "velden.gpkg"))) {
  jachtgebieden %>%
    read_sf() %>%
    filter(!is.na(.data$WBENR)) %>%
    st_transform(crs = 31370) %>%
    select(wbe = .data$WBENR, veld = .data$VELDID) -> jacht
  qgis_run_algorithm(
    "native:buffer",
    INPUT = jacht, DISTANCE = -0.1, DISSOLVE = FALSE,
    END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5
  ) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:dissolve",
        FIELD = c("wbe", "veld"),
        OUTPUT = here(target_folder, "velden.gpkg")
      )
    ) %>%
    do.call(what = qgis_run_algorithm)
}

message("kader 1")
if (!file.exists(here(target_folder, "kader_01_basis.gpkg"))) {
  qgis_run_algorithm(
    "native:intersection",
    INPUT = here(target_folder, "velden.gpkg"),
    INPUT_FIELDS = c("wbe", "veld"),
    OVERLAY = here(target_folder, "open_ruimte.gpkg"),
    OVERLAY_FIELDS = "open_id",
    OVERLAY_FIELDS_PREFIX = ""
  ) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:dissolve", FIELD = c("wbe", "veld"), .quiet = TRUE
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de breedte van de bounding box in hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "dx",
        FORMULA = "bounds_width($geometry) / 100"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de hoogte van de bounding box in hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "dy",
        FORMULA = "bounds_height($geometry) / 100"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de oppervlakte in ha
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "ha",
        FORMULA = "$area / 10000"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bepaal polygonen breder of hoger dan 27 hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "te_breed",
        FORMULA = "if(if( dx > dy,dx, dy) > 27, 1, 0)", FIELD_TYPE = 1
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bepaal polygonen breder of hoger dan 19 hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "te_hoog",
        FORMULA = "if(if( dx > dy, dy, dx) > 19, 1, 0)", FIELD_TYPE = 1
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de verhouding oppervlakte / bounding box
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "ratio",
        FORMULA = "ha / dx / dy",
        OUTPUT = sprintf("%s/kader_01_basis.gpkg", target_folder)
      )
    ) %>%
    do.call(what = qgis_run_algorithm)
}

if (!file.exists(here(target_folder, "kader_01.gpkg"))) {
  # selecteer jachtvelden die we niet hoeven splitsen
  qgis_run_algorithm(
    "native:extractbyexpression",
    INPUT = sprintf("%s/kader_01_basis.gpkg", target_folder),
    EXPRESSION =
    "NOT (ha > 150 OR te_breed = 1 OR te_hoog = 1 OR (ratio < 0.1 AND ha > 1))",
    OUTPUT = sprintf("%s/kader_01_ok.gpkg", target_folder)
  )

  # selecteer te splitsen jachtvelden
  qgis_run_algorithm(
    "native:extractbyexpression",
    INPUT = sprintf("%s/kader_01_basis.gpkg", target_folder),
    EXPRESSION =
      "ha > 150 OR te_breed = 1 OR te_hoog = 1 OR (ratio < 0.1 AND ha > 1)"
  ) %>% qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(algorithm = "native:multiparttosingleparts")) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de breedte van de bounding box in hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "dx",
        FORMULA = "bounds_width($geometry) / 100"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de hoogte van de bounding box in hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "dy",
        FORMULA = "bounds_height($geometry) / 100"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de oppervlakte in ha
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "ha",
        FORMULA = "$area / 10000"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bepaal polygonen breder of hoger dan 27 hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "te_breed",
        FORMULA = "if(if( dx > dy,dx, dy) > 27, 1, 0)", FIELD_TYPE = 1
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bepaal polygonen breder of hoger dan 19 hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "te_hoog",
        FORMULA = "if(if( dx > dy, dy, dx) > 19, 1, 0)", FIELD_TYPE = 1
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de verhouding oppervlakte / bounding box
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "ratio",
        FORMULA = "ha / dx / dy",
        OUTPUT = sprintf("%s/kader_01.gpkg", target_folder)
      )
    ) %>%
    do.call(what = qgis_run_algorithm)
}

if (!file.exists(here(target_folder, "level_01.gpkg"))) {
  wegen %>%
    read_sf() %>%
    filter(LBLWEGCAT %in% c("hoofdweg", "primaire weg I")) %>%
    st_transform(crs = 31370) %>%
    select(LBLWEGCAT) -> hoofdweg
  waterlopen %>%
    read_sf() %>%
    filter(LBLCATC %in% c("Bevaarbaar")) %>%
    st_transform(crs = 31370) %>%
    select(LBLCATC) -> bevaarbaar
  vlaanderen %>%
    read_sf() %>%
    st_transform(crs = 31370) %>%
    st_write(
      dsn = here(target_folder, "vlaanderen.shp"),
      delete_dsn = file.exists(
        here(target_folder, "vlaanderen.shp")
      )
    )
  qgis_run_algorithm(
    "native:buffer", INPUT = bevaarbaar, DISTANCE = 20, DISSOLVE = TRUE,
    END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5
  ) %>%
    qgis_output("OUTPUT") %>%
    as.character() -> bevaarbaar
  qgis_run_algorithm(
    "native:buffer", INPUT = hoofdweg, DISTANCE = 20, DISSOLVE = TRUE,
    END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5
  ) %>%
    qgis_output("OUTPUT") %>%
    setNames("OVERLAY") %>%
    c(
      list(
        algorithm = "native:difference",
        INPUT = here(target_folder, "vlaanderen.shp")
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(algorithm = "native:difference", OVERLAY = bevaarbaar)) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(algorithm = "native:multiparttosingleparts")) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:buffer", DISTANCE = 19.8, DISSOLVE = FALSE,
        END_CAP_STYLE = 0, JOIN_STYLE = 0, MITER_LIMIT = 2, SEGMENTS = 5
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    read_sf() %>%
    mutate(level1 = row_number()) %>%
    select(-OIDN) %>%
    st_write(
      dsn = here(target_folder, "level_01.gpkg"),
      delete_dsn = file.exists(
        here(target_folder, "level_01.gpkg")
      )
    )
}

refine_level <- function(
    current_level, target_folder, split_laag, split_var, split_val
) {
  # selecteer nieuwe grenzen
  qgis_run_algorithm(
    "native:extractbyexpression",
    INPUT = split_laag,
    EXPRESSION = paste0(split_var, " = '", split_val, "'", collapse = " OR ")
  ) %>%
    qgis_output("OUTPUT") %>%
    unclass() -> split_laag
  # selecteer te verkleinen polygonen van steekproefkader
  qgis_run_algorithm(
    "native:extractbyexpression",
    INPUT = sprintf("%s/kader_%02i.gpkg", target_folder, current_level),
    EXPRESSION =
      "ha > 100 OR te_breed = 1 OR te_hoog = 1 OR (ratio < 0.1 AND ha > 1)"
  ) %>%
    qgis_output("OUTPUT") %>%
    # selecteer de overeenkomstige eiland polygonen
    setNames("INTERSECT") %>%
    c(
      list(
        algorithm = "native:extractbylocation",
        INPUT = sprintf("%s/level_%02i.gpkg", target_folder, current_level)
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    unclass() -> level_selectie
  # snijd de beschikbare grenzen bij aan de hand van de geselecteerde eiland
  # polygonen
  qgis_run_algorithm(
    "native:clip", INPUT = split_laag, OVERLAY = level_selectie
  ) %>%
    qgis_output("OUTPUT") %>%
    # buffer de overgebleven grenzen
    setNames("INPUT") %>%
    c(list(algorithm = "native:buffer", DISTANCE = 10)) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # knip de buffers uit de eiland polygonen
    setNames("OVERLAY") %>%
    c(
      list(
        algorithm = "native:difference",
        INPUT = sprintf("%s/level_%02i.gpkg", target_folder, current_level)
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # split de nieuwe eilandpolygonen in afzonderlijke polygonen
    setNames("INPUT") %>%
    c(list(algorithm = "native:multiparttosingleparts")) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # voeg een nieuwe id toe aan de eilandpolygonen
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:addautoincrementalfield",
        FIELD_NAME = paste0("level", current_level + 1),
        OUTPUT = sprintf("%s/level_%02i.gpkg", target_folder, current_level + 1)
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # versnij de eilandpolygonen met het basissteekproefkader
    setNames("OVERLAY") %>%
    c(
      list(
        algorithm = "native:intersection",
        INPUT = here(target_folder, "kader_01.gpkg"),
        INPUT_FIELDS = c("wbe", "veld", "open_id"),
        OVERLAY_FIELDS = paste0("level", seq_len(current_level + 1)),
        OVERLAY_FIELDS_PREFIX = ""
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # zet het steekproefkader om naar enkelvoudige polygonen
    setNames("INPUT") %>%
    c(list(algorithm = "native:multiparttosingleparts")) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de breedte van de bounding box in hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "dx",
        FORMULA = "bounds_width($geometry) / 100"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de hoogte van de bounding box in hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "dy",
        FORMULA = "bounds_height($geometry) / 100"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de oppervlakte in ha
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "ha",
        FORMULA = "$area / 10000"
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bepaal polygonen breder of hoger dan 27 hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "te_breed",
        FORMULA = "if(if( dx > dy,dx, dy) > 27, 1, 0)", FIELD_TYPE = 1
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bepaal polygonen breder of hoger dan 19 hm
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "te_hoog",
        FORMULA = "if(if( dx > dy, dy, dx) > 19, 1, 0)", FIELD_TYPE = 1
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    # bereken de verhouding oppervlakte / bounding box
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:fieldcalculator", FIELD_NAME = "ratio",
        FORMULA = "ha / dx / dy",
        OUTPUT = sprintf("%s/kader_%02i.gpkg", target_folder, current_level + 1)
      )
    ) %>%
    do.call(what = qgis_run_algorithm)
  qgis_tmp_clean()
}

message("kader 2")
if (!file.exists(here(target_folder, "kader_02.gpkg"))) {
  refine_level(
    current_level = 1, split_laag = waterlopen, split_var = "LBLCATC",
    split_val = "Geklasseerd, eerste categorie", target_folder = target_folder
  )
}

message("kader 3")
if (!file.exists(here(target_folder, "kader_03.gpkg"))) {
  refine_level(
    current_level = 2, split_laag = spoorwegen, split_var = "FID",
    split_val = 0, target_folder = target_folder
  )
}

message("kader 4")
if (!file.exists(here(target_folder, "kader_04.gpkg"))) {
  refine_level(
    current_level = 3, split_laag = wegen, split_var = "LBLWEGCAT",
    split_val = "primaire weg II", target_folder = target_folder
  )
}

message("kader 5")
if (!file.exists(here(target_folder, "kader_05.gpkg"))) {
  refine_level(
    current_level = 4, split_laag = wegen, split_var = "LBLWEGCAT",
    split_val = c(
      "secundaire weg type 1", "secundaire weg type 2", "secundaire weg type 3"
    ), target_folder = target_folder
  )
}

message("kader 6")
if (!file.exists(here(target_folder, "kader_06.gpkg"))) {
  refine_level(
    current_level = 5, split_laag = wegen, split_var = "LBLWEGCAT",
    split_val = "lokale weg type 1", target_folder = target_folder
  )
}

message("kader 7")
if (!file.exists(here(target_folder, "kader_07.gpkg"))) {
  refine_level(
    current_level = 6, split_laag = wegen, split_var = "LBLWEGCAT",
    split_val = "lokale weg type 2", target_folder = target_folder
  )
}

message("kader 8")
if (!file.exists(here(target_folder, "kader_08.gpkg"))) {
  refine_level(
    current_level = 7, split_laag = wegen, split_var = "LBLWEGCAT",
    split_val = "lokale weg type 3", target_folder = target_folder
  )
}

message("kader 9")
if (!file.exists(here(target_folder, "kader_09.gpkg"))) {
  refine_level(
    current_level = 8, split_laag = wegen, split_var = "LBLWEGCAT",
    split_val = "niet van toepassing", target_folder = target_folder
  )
}

message("kader 10")
if (!file.exists(here(target_folder, "kader_10.gpkg"))) {
  refine_level(
    current_level = 9, split_laag = waterlopen, split_var = "LBLCATC",
    split_val = "Geklasseerd, tweede categorie", target_folder = target_folder
  )
}

message("kader 11")
if (!file.exists(here(target_folder, "kader_11.gpkg"))) {
  refine_level(
    current_level = 10, split_laag = waterlopen, split_var = "LBLCATC",
    split_val = "Geklasseerd, derde categorie", target_folder = target_folder
  )
}

message("kader 12")
if (!file.exists(here(target_folder, "kader_12.gpkg"))) {
  refine_level(
    current_level = 11, split_laag = waterlopen, split_var = "LBLCATC",
    split_val = "Niet geklasseerd", target_folder = target_folder
  )
}

message("kader 13")
if (!file.exists(here(target_folder, "kader_13.gpkg"))) {
  refine_level(
    current_level = 12, split_laag = extra_grenzen, split_var = "gebruik",
    split_val = "X", target_folder = target_folder
  )
}

# voeg kleine delen samen
here(target_folder, "kader_13.gpkg") %>%
  setNames("INPUT") %>%
  c(
    list(
      algorithm = "native:fieldcalculator", FIELD_NAME = "xmin",
      FORMULA = "xmin($geometry)", .quiet = TRUE
    )
  ) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(
    list(
      algorithm = "native:fieldcalculator", FIELD_NAME = "xmax",
      FORMULA = "xmax($geometry)", .quiet = TRUE
    )
  ) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(
    list(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ymin",
      FORMULA = "ymin($geometry)", .quiet = TRUE
    )
  ) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  setNames("INPUT") %>%
  c(
    list(
      algorithm = "native:fieldcalculator", FIELD_NAME = "ymax",
      FORMULA = "ymax($geometry)", .quiet = TRUE
    )
  ) %>%
  do.call(what = qgis_run_algorithm) %>%
  qgis_output("OUTPUT") %>%
  read_sf() %>%
  filter(ha >= 0.01) -> basis
qgis_tmp_clean()

done <- list.files(here(target_folder, "veld"), pattern = "veld.*\\.gpkg")
done <- as.integer(gsub(".*([0-9]{8}).*", "\\1", done))
to_do <- as.integer(sort(unique(basis$veld)))
for (i in to_do[!to_do %in% done]) {
  basis %>%
    filter(.data$veld == i) -> dit_veld
  sprintf("veld: %i, max: %.0f", i, max(dit_veld$ha)) %>%
    message()
  while (min(dit_veld$ha) < 50) {
    klein <- dit_veld[which.min(dit_veld$ha), ]
    dit_veld <- dit_veld[-which.min(dit_veld$ha), ]
    dx <- pmax(klein$xmax, dit_veld$xmax) - pmin(klein$xmin, dit_veld$xmin)
    dy <- pmax(klein$ymax, dit_veld$ymax) - pmin(klein$ymin, dit_veld$ymin)
    j <- which(
      pmax(dx, dy) < 2700 & pmin(dx, dy) < 1900 & dit_veld$ha < 125
    )
    if (length(j) == 0) {
      klein$ha <- Inf
      dit_veld <- bind_rows(dit_veld, klein)
      next
    }
    k <- which(dit_veld$veld[j] == klein$veld & dit_veld$ha[j] < 100)
    if (length(k) == 0) {
      k <- which(dit_veld$level2[j] == klein$level2 & dit_veld$ha[j] < 125)
    }
    if (length(k) == 0) {
      k <- which(dit_veld$level1[j] == klein$level1 & dit_veld$ha[j] < 125)
    }
    if (length(k) == 0) {
      klein$ha <- Inf
      dit_veld <- bind_rows(dit_veld, klein)
      next
    }
    j <- j[k]
    dit_veld[j, ] %>%
      st_distance(klein) %>%
      which.min() -> k
    j <- j[k]
    dit_veld$ha[j] <- dit_veld$ha[j] + klein$ha
    dit_veld$xmin[j] <- pmin(dit_veld$xmin[j], klein$xmin)
    dit_veld$xmax[j] <- pmax(dit_veld$xmax[j], klein$xmax)
    dit_veld$ymin[j] <- pmin(dit_veld$ymin[j], klein$ymin)
    dit_veld$ymax[j] <- pmax(dit_veld$ymax[j], klein$ymax)
    dit_veld$geom[j] %>%
      st_union(klein$geom) %>%
      st_union() -> dit_veld$geom[j]
    next
  }

  sprintf("%.0f - %.0f", min(dit_veld$ha), max(dit_veld$ha)) %>%
    message()

  qgis_run_algorithm(
    "native:extractbyattribute",
    INPUT = here(target_folder, "kader_01.gpkg"),
    FIELD = "veld", VALUE = i, .quiet = TRUE, OPERATOR = "=",
    OUTPUT = qgis_tmp_vector(), FAIL_OUTPUT = qgis_tmp_vector()
  ) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:union", .quiet = TRUE, OUTPUT = qgis_tmp_vector(),
      OVERLAY = NULL, OVERLAY_FIELDS_PREFIX = NULL
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:multiparttosingleparts", .quiet = TRUE,
      OUTPUT = qgis_tmp_vector()
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    unclass() -> deze_open
  dit_veld %>%
    transmute(
      veld = as.integer(.data$veld), id = sprintf("%s%02i", veld, row_number())
    ) %>%
    list() %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:buffer", DISTANCE = 20, .quiet = TRUE, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector(), END_CAP_STYLE = "Round", JOIN_STYLE = "Round",
      MITER_LIMIT = 2, DISSOLVE = FALSE
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(list(
      algorithm = "native:buffer", DISTANCE = -20, .quiet = TRUE, SEGMENTS = 5,
      OUTPUT = qgis_tmp_vector(), END_CAP_STYLE = "Round", JOIN_STYLE = "Round",
      MITER_LIMIT = 2, DISSOLVE = FALSE
    )) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:intersection", OVERLAY = deze_open,
        INPUT_FIELDS = c("veld","id"), OVERLAY_FIELDS = "fid",
        OVERLAY_FIELDS_PREFIX = "or_", .quiet = TRUE, OUTPUT = qgis_tmp_vector()
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:dissolve", FIELD = c("veld", "id"), .quiet = TRUE,
        OUTPUT = qgis_tmp_vector()
      )
    ) %>%
    do.call(what = qgis_run_algorithm) %>%
    qgis_output("OUTPUT") %>%
    setNames("INPUT") %>%
    c(
      list(
        algorithm = "native:deletecolumn", COLUMN = c("fid", "or_fid"),
        .quiet = TRUE,
        OUTPUT = here(target_folder, "veld", paste0("veld_", i, ".gpkg"))
      )
    ) %>%
    do.call(what = qgis_run_algorithm)
  qgis_tmp_clean()
}

here(target_folder, "kader_01_ok.gpkg") %>%
  read_sf() %>%
  transmute(
    veld = as.integer(veld), id = as.character(row_number())
  ) -> steekproefkader
here(target_folder, "veld") %>%
  list.files(pattern = "veld.*\\.gpkg", full.names = TRUE) -> to_do
for (i in to_do) {
  read_sf(i) %>%
    bind_rows(steekproefkader) -> steekproefkader
}
steekproefkader %>%
  mutate(
    wbe = str_sub(.data$veld, 1, 3) %>%
      as.integer(),
    veld = str_sub(.data$veld, 4) %>%
      as.integer()
  ) %>%
  group_by(veld) %>%
  mutate(telblok = row_number()) %>%
  ungroup() %>%
  arrange(desc(telblok))
  mutate(
    id = (.data$wbe * 1000 + .data$veld) * 1000 + .data$telblok,
    controle = id %% 97,
    id = sprintf(
      "%03i-%03i-%02i-%02i",
      .data$wbe, .data$veld, .data$telblok, .data$controle
    ),
    landscape = map(.data$geom, st_bbox) %>%
      map_lgl(
        function(x) {
          (x["xmax"] - x["xmin"]) > (x["ymax"] - x["ymin"])
        }
      ),
    ha = st_area(.) %>%
      as.vector() %>%
      `/`(1e4)
  ) %>%
  select(.data$id, .data$wbe, .data$veld, .data$ha, .data$landscape) %>%
  arrange(wbe, veld, id) %>%
  st_write(
    dsn = here(target_folder, "steekproefkader.shp"),
    delete_dsn = file.exists(here(target_folder, "steekproefkader.shp"))
  )
qgis_run_algorithm(
  "native:createspatialindex",
  INPUT = here(target_folder, "steekproefkader.shp")
)

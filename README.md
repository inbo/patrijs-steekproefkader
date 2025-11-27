<!-- badges: start -->
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.5814813.svg)](https://doi.org/10.5281/zenodo.5814813)
[![website](https://img.shields.io/badge/website-https%3A%2F%2Finbo.github.io%2Fpatrijs--steekproefkader%2F-c04384)](https://inbo.github.io/patrijs-steekproefkader/)
[![Project Status: Concept - Minimal or no implementation has been done yet, or the repository is only intended to be a limited example, demo, or proof-of-concept.](https://www.repostatus.org/badges/latest/concept.svg)](https://www.repostatus.org/#concept)
[![Lifecycle: experimental](https://img.shields.io/badge/lifecycle-experimental-orange.svg)](https://lifecycle.r-lib.org/articles/stages.html#experimental)
[![CC BY 4.0](https://img.shields.io/badge/License-CC_BY_4.0-brightgreen)](https://raw.githubusercontent.com/inbo/checklist/refs/heads/main/inst/generic_template/cc_by_4_0.md)
[![Release](https://img.shields.io/github/release/inbo/patrijs-steekproefkader.svg)](https://github.com/inbo/patrijs-steekproefkader/releases)
![GitHub Workflow Status](https://img.shields.io/github/actions/workflow/status/inbo/patrijs-steekproefkader/check-project)
![GitHub repo size](https://img.shields.io/github/repo-size/inbo/patrijs-steekproefkader)
![GitHub code size in bytes](https://img.shields.io/github/languages/code-size/inbo/patrijs-steekproefkader.svg)
<!-- badges: end -->

# Sampling frame for partridge (_Perdrix perdrix_) in Flanders

[Onkelinx, Thierry![ORCID logo](https://info.orcid.org/wp-content/uploads/2019/11/orcid_16x16.png)](https://orcid.org/0000-0001-8804-4216)[^aut][^cre][^INBO];
[Carmen, Raïsa![ORCID logo](https://info.orcid.org/wp-content/uploads/2019/11/orcid_16x16.png)](https://orcid.org/0000-0003-1025-8702)[^aut][^INBO];
[Research Institute for Nature and Forest (INBO)](mailto:info%40inbo.be)[^cph][^fnd]

[^aut]: author
[^cph]: copyright holder
[^cre]: contact person
[^fnd]: funder
[^INBO]: Research Institute for Nature and Forest (INBO)

**keywords**: hunting; monitoring; habitat

<!-- version: 2025.05 -->
<!-- community: inbo -->

<!-- description: start -->
Since 2008, partridge hunting in Flanders has been subject to a number of conditions.
The first condition states compliance with an average density of at least 3 breeding pairs per 100 ha of open space.
The Research Institute for Nature and Forest ([INBO](https://www.vlaanderen.be/inbo/en)) is responsible for the calculation of these densities and advises the Agency for Nature and Forests ([ANB](https://www.natuurenbos.be/)) on this.

This repository contains the source code to generate the layer with open space within [hunting grounds](https://doi.org/10.5281/zenodo.5584203) in Flanders.
The selection is based on relevant categories of the [OpenStreetMap](https://openstreetmap.org) information.

We aim to make the layer reproducible by making the code publicly available under an open source license.
The code itself requires only freeware open source software ([R](https://www.r-project.org/) and [QGIS](https://qgis.org)).
The OpenStreetMap database updates continuously.
Rerunning the code on the current database might yield a different layer.
Therefore we also republish the [snapshot](https://doi.org/10.5281/zenodo.5792948) of the OpenStreetMap data we used.
When we need to update the open space layer, we will add an updated snapshot as a new version.
Having both the code and the data available under version control, allows to recreate both the most recent version as any older version.
<!-- description: end -->

## Available maps for field work

### Areal photograph as background

- **West-Flanders**: https://doi.org/10.5281/zenodo.5812597
- **East-Flanders**: https://doi.org/10.5281/zenodo.5814972
- **Antwerp**: https://doi.org/10.5281/zenodo.5815049
- **Limburg**: https://doi.org/10.5281/zenodo.5815083
- **Flemish Brabant**: https://doi.org/10.5281/zenodo.5815089

### OpenStreetMap as background

- **West-Flanders**: https://doi.org/10.5281/zenodo.5815407
- **East-Flanders**: https://doi.org/10.5281/zenodo.5815400
- **Antwerp**: https://doi.org/10.5281/zenodo.5815392
- **Limburg**: https://doi.org/10.5281/zenodo.5815379
- **Flemish Brabant**: https://doi.org/10.5281/zenodo.5815209

### Cartoweb as background

- **West-Flanders**: https://doi.org/10.5281/zenodo.5827428
- **East-Flanders**: https://doi.org/10.5281/zenodo.5831528
- **Antwerp**: https://doi.org/10.5281/zenodo.5827467
- **Limburg**: https://doi.org/10.5281/zenodo.5827491
- **Flemish Brabant**: https://doi.org/10.5281/zenodo.5827509

## Other maps

- **open area for partridge**: https://doi.org/10.5281/zenodo.5814833
- **sampling units**: https://doi.org/10.5281/zenodo.5814900
- **hunting grounds**: https://doi.org/10.5281/zenodo.5584203
- **OpenStreetMap snapshot**: https://doi.org/10.5281/zenodo.5792948

# How to update the maps

## Downloading and republish the source data

1. `source/zenodo/update_osm_pbf.R` handles the OpenStreetMap data.
1. `source/zenodo/update_jacht.R` handles the hunting area data.
  Note that you need to update the URL, publication date and version.

## Updating the open area layer

1. Delete the `data/open_area` folder.
1. `source/create_map/create_map.R` is the main script to create the open area map.
  It calls `source/create_map/download.R` and `source/create_map/hunting_grounds.R` if required.
1. `source/create_map/sampling.R` splits the open area map into sampling areas.
1. `source/create_map/atlas.R` creates a set of pdf's for every sampling area.

<!-- badges: start -->
[![DOI](https://zenodo.org/badge/DOI/10.5281/zenodo.5814813.svg)](https://doi.org/10.5281/zenodo.5814813)
[![website](https://img.shields.io/badge/website-https%3A%2F%2Finbo.github.io%2Fpatrijs--steekproefkader%2F-c04384)](https://inbo.github.io/patrijs-steekproefkader/)
![GitHub](https://img.shields.io/github/license/inbo/patrijs-steekproefkader)
![GitHub release (latest by date)](https://img.shields.io/github/v/release/inbo/patrijs-steekproefkader)
![GitHub Release Date](https://img.shields.io/github/release-date/inbo/patrijs-steekproefkader)
![GitHub Workflow Status](https://img.shields.io/github/workflow/status/inbo/patrijs-steekproefkader/check-source)
![GitHub repo size](https://img.shields.io/github/repo-size/inbo/patrijs-steekproefkader)
<!-- badges: end -->
  
# Sampling frame for partridge (_Perdrix perdrix_) in Flanders

[Onkelinx, Thierry![ORCID logo](https://info.orcid.org/wp-content/uploads/2019/11/orcid_16x16.png)](https://orcid.org/0000-0001-8804-4216)[^aut][^cre][^INBO];
[Carmen, Raïsa![ORCID logo](https://info.orcid.org/wp-content/uploads/2019/11/orcid_16x16.png)](https://orcid.org/0000-0003-1025-8702)[^aut][^INBO];
Research Institute for Nature and Forest (INBO)[^cph][^fnd]

[^aut]: author
[^cre]: contact person
[^cph]: copyright holder
[^fnd]: funder
[^INBO]: Research Institute for Nature and Forest (INBO)

**keywords**: hunting; monitoring; habitat

<!-- version: 2023.01 -->
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

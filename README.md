# Sampling frame for partridge (_Perdrix perdrix_) in Flanders

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

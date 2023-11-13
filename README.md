BACPAC Spring Meeting 2023 Demo Analysis
========================================

This repository contains an analsys of some of the combined minimum
data sets available on the BACPAC Data Portal using both Python and R.

Running the Code
================

This workflow is Dockerized although you'll need the source Docker
container (contact toups@unc.edu) to be loaded on the BACPAC virtual
Machine in order to build the container. With the container built you
can start R Studio, Jupyter Lab or Emacs using the start.sh
script. (Because of the limitations on the internet connections on
Data Portal VMS the base machine needs to be built outside and
uploaded).

Before running the code make a copy of the entire canonical data
directory into this folder.

```
cp -r /mnt/containers/canonical .
```

```
docker build . -t march
bash start.sh -e emacs -c march
;;or
bash start.sh -e jupyter -c march
;;or 
bash start.sh -e rstudio -c march
```

This will start a full development environment. The best place to get
started is the Makefile, which contains the workflow. Most users
interested in getting started will want to build the data set meta-data:

```
make derived_data/meta-data.csv
```

This collects all the data sets and records their institution, scheme,
location on the file system, minimum data set domain and other
information.

Interactive Visualization
===============================

To run the vizualization from the November Meeting, start the
container with port 8888 exported and run

```
make interactive
```

This should construct all the intermediate data sets and analyses
required for the visualizatio and start a Jupyter Lab instance on port
8888.

If you launched the container with something like:

```
docker run -p 8888:8888 ...
```

Then you should be able to copy the link printed out by this
invocation and open it in your browser, which should show the
visualization notebook.



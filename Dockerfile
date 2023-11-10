FROM r-user-correct
USER root
RUN usermod -u 1007 rstudio
RUN groupmod -g 1007 rstudio
RUN pip3 install pyarrow polars
RUN R -e "install.packages(\"pracma\")"
RUN pip3 install isoduration

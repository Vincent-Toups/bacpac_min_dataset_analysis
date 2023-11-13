.PHONY: clean
.PHONY: purge

## NB. this repo assumes you've mounted a _COPY_ of the canonical
## space inside the docker container at ./canonical
## and that the space is read/writeable. If you really need to
## totally reset this project, you should delete that copy
## and make a fresh one from the actual canonical directory.
clean: 
	rm -rf figures && mkdir -p figures
	rm -rf derived_data && mkdir -p derived_data

## This task finds all the zip files in the canonical directory.
derived_data/zip-files.txt: 
	find . -type f -iname "*.zip" > derived_data/zip-files.txt
	head derived_data/zip-files.txt

## Our strategy is to unzip all the zip files
## and then convert all the xpt files to csv
## and then operate only on csv files from then on.
derived_data/unzipped-everything: derived_data/zip-files.txt
	rm -f derived_data/unzipped-everything
	emacs --script unzip-everything.el

## Once we have unzipped all the files from the copy of the Canonical
## directory, we load and convert all the xpt files to csv files so
## everything can be processed uniformly.
derived_data/xpt-files.txt: derived_data/unzipped-everything
	find . -type f -iname "*.xpt" | grep -v __MACOSX > derived_data/xpt-files.txt
	exit 0

## Produce a list of all the csv files in the canonical directory
## after unzipping and converting everything to csv.
derived_data/csv-files.txt: derived_data/xpt-files.txt
	Rscript convert-xpt-to-csv.R
	find . -type f -iname "*.csv" | grep canonical | grep -v __MACOSX > derived_data/csv-files.txt 
	head derived_data/csv-files.txt

# Make a meta-data file consisting of all the CSV files we have with
# the number of rows and domain, if applicable.  Also, the column
# names. The meta-data also distinguishes between ARCHIVEd data and
# minimum data set and non-minimum dataset data.
derived_data/meta-data.csv: derived_data/csv-files.txt
	Rscript enumerate-schemas.R


## For all subjects which have this data, gather and plot the change
## in their pain interfence measures as a function of time. 
figures/ts-pain-interference.png\
derived_data/subject-changes.csv: responders.py\
 derived_data/meta-data.csv
	python3 responders.py

## For the purposes of visualization we train a variation auto-encoder
## for our demographic data. An attempt is made to determine whether
## demographic data is related to outcomes (for those patients where
## we have the data).
derived_data/demographics-with-projection.csv\
 derived_data/demo-encoded.csv\
 figures/race-ethnicity-projection.png\
 figures/old-race-ethnicity-projection.png\
 figures/race-ethnicity-projection-studyid.png\
 figures/race-ethnicity-projection-studyid-faceted.png\
 figures/race-ethnicity-projection-density-studyid-faceted.png\
 figures/race-ethnicity-projection-studyid-faceted-filled.png\
 figures/race-ethnicity-responders.png\
 figures/race-ethnicity-responders-continuous.png: derived_data/meta-data.csv derived_data/subject-changes.csv vae-demographics.py
	python3 vae-demographics.py

## Load, concatenate and save all the FT data.
derived_data/ft_combined.csv: derived_data/meta-data.csv ft.py
	python3 ft.py

## Load, concatenate and save all the EX data.
derived_data/ex_combined.csv: derived_data/meta-data.csv ex.py
	python3 ex.py

## Experiment to train a neural network to predict response from EX
## data.
figures/nn_response_mode.png: derived_data/ex-wide-gbm-encoded.csv response-model.py
	python3 response-model.py


## Build a VAE for subject characteristics.
derived_data/sc-encoded.csv\
 derived_data/subject-chars-with-projection.csv\
 figures/sc_by_study.png\
 figures/sc_by_study_facet.png: derived_data/meta-data.csv subject-characteristics-vae.py
	python3 subject-characteristics-vae.py

## Characterize the treatment model we built above via an ROC curve.
figures/treatment-model-roc.png: derived_data/meta-data.csv derived_data/subject-changes.csv ex-responders.R
	Rscript ex-responders.R

## An attempt to produce a VAE for a smaller subset of demographic
## data.
derived_data/reduced-demographics-one-hot.csv: source_data/demographics.csv reduced-demographic-ae.py
	python3 reduced-demographic-ae.py

## Produce PEG score traces.
derived_data/subject-changes-peg-score.csv derived_data/peg_score_ts.csv figures/change-distribution.png figures/ts-peg-score.png: derived_data/meta-data.csv responders-peg-score.py
	python3 responders-peg-score.py

## An attempt to visualize the demographic projection via density
## plot.
figures/filled_density_faceted_plot.png figures/filled_density_faceted_plot_outcome.png: derived_data/demographics-with-projection.csv demo_filled_density.R
	Rscript demo_filled_density.R

## Write out the FT data set for use in interactive visualizations.
figures/ft_counts.png figures/ft_vectors.png: derived_data/ft_combined.csv ft.R
	Rscript ft.R

## Write out the EX data set for use in interactive visualizations.
figures/ex_treatments.png figures/treatment_imagesc.png figures/treatment_pca_imagesc.png figures/treatment_clustered_imagesc.png: derived_data/ex_combined.csv ex.R
	Rscript ex.R

## Set up the Jupyter Notebook
.PHONY: interactive
interactive: derived_data/demographics-with-projection.csv derived_data/subject-chars-with-projection.csv derived_data/pain-interference-smoothed.csv ./derived_data/peg_score_ts.csv
	jupyter lab --ip 0.0.0.0 --port 8888 Interactive-fiddling-dynamics-titles.ipynb

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

## Our strategy is to unzip all the zip files
## and then convert all the xpt files to csv
## and then operate only on csv files from then on.
derived_data/unzipped-everything: derived_data/zip-files.txt
	rm -f derived_data/unzipped-everything
	emacs --script unzip-everything.el

derived_data/xpt-files.txt: derived_data/unzipped-everything
	find . -type f -iname "*.xpt" | grep -v __MACOSX > derived_data/xpt-files.txt
	exit 0

derived_data/zip-files.txt:
	find . -type f -iname "*.zip" > derived_data/zip-files.txt
	head derived_data/zip-files.txt

derived_data/csv-files.txt: derived_data/xpt-files.txt
	Rscript convert-xpt-to-csv.R
	find . -type f -iname "*.csv" | grep canonical | grep -v __MACOSX > derived_data/csv-files.txt 
	head derived_data/csv-files.txt

# Make a meta-data file consisting of all the CSV files we have
# with the number of rows and domain, if applicable.
# Also, the column names.
derived_data/meta-data.csv: derived_data/csv-files.txt
	Rscript enumerate-schemas.R

figures/ts-pain-interference.png\
derived_data/subject-changes.csv: \
 responders.py\
 derived_data/meta-data.csv
	python3 responders.py

figures/race-ethnicity-responders.png\
figures/race-ethnicity-projection-studyid.png\
figures/race-ethnicity-projection.png\
derived_data/demo-encoded.csv: vae-demographics.py\
  derived_data/meta-data.csv derived_data/subject-changes.csv
	python3 vae-demographics.py

figures/eco_etc_projection.png derived_data/eco-encoded.csv:\
 eco-vae.py derived_data/meta-data.csv derived_data/subject-changes.csv
	python3 eco-vae.py

figures/gbm-vars-responders.png:\
 gbm-responders.R\
 derived_data/subject-changes.csv\
 derived_data/eco-encoded.csv\
 derived_data/demo-encoded.csv
	Rscript gbm-responders.R

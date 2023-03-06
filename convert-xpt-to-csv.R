library(tidyverse)
library(haven)

make_line_logger <- function(filename, clear=T){
    if (file.exists(filename)) file.remove(filename);
    function(...){
        cat(sprintf(...),file=filename,sep="\n",append=T);
    }
}

logger <- make_line_logger("derived_data/xpt_to_csv_files.txt");

xpt_files <- read.csv("derived_data/xpt-files.txt", header=F) %>% as_tibble();

for (file in xpt_files$V1) {
    tryCatch({
        x <- read_xpt(file);
        outname <- file %>% str_replace_all(c("\\.xpt"=".csv","\\.XPT"=".csv"))
        write_csv(x,outname);
        logger(outname);
    },error= function (e) {
        print(sprintf("Error converting %s to csv (outname: %s).",file, outname));
        print(e);
    })
 }


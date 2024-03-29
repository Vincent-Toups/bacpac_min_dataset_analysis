library(tidyverse);

## for some reason we can't print this object
csv_files <- read_csv("derived_data/csv-files.txt", col_names="file");

s <- c();
f <- c();
domain <- c();
rows <- c();

na_to_false <- function(a){
    nas <- is.na(a);
    a[nas] <- FALSE;
    a    
}

tidymap <- function(s,f){
  Map(f,s);
  
}

for (file in csv_files$file) {
    d <- read_csv(file, show_col_types=F, progress=FALSE);
    nd <- names(d) %>% paste(collapse=", ");
    s <- c(s,nd);
    if ("DOMAIN" %in% names(d)){
        domain <- c(domain, d$DOMAIN[[1]]);               
    } else {
        domain <- c(domain, NA);
    }
    rows <- c(rows, nrow(d));
}

missing_site_map <- function(sitemap, current_leading_dirs){
    missing_dirs <- setdiff(current_leading_dirs, names(sitemap))
    return(missing_dirs)
}

site_map <- list(
    "CCS_BESTTrial"="CCS",
    "CCS_BESTTrial-arch"="CCS",
    "BESTTrial"="UNC",
    "BESTTrial-arch"="UNC",
    "OSUTechSite"="OSUTechSite",
    "OSUTechSite-arch"="OSUTechSite",
    "PittMRC"="Pitt",
    "PittMRC-arch"="Pitt",
    "TM_AOFoundation"="AOFoundation",
    "TM_AOFoundation-arch"="AOFoundation",
    "TM_CedarsSinai"="CedarsSinai",
    "TM_CedarsSinai-arch"="CedarsSinai",
    "TM_Dartmouth"="Dartmouth",
    "TM_Dartmouth-arch"="Dartmouth",
    "TM_QuebecLBPStudy"="Quebec",
    "TM_QuebecLBPStudy-arch"="Quebec",
    "TM_UMichAPOLO"="UMich",
    "TM_UMichAPOLO-arch"="UMich",
    "TM_Vanderbilt"="Vanderbilt",
    "TM_Vanderbilt-arch"="Vanderbilt",
    "TM_Stanford-arch"="Stanford",
    "TM_Stanford"="Stanford",    
    "UCSFMRC"="UCSF",
    "UCSFMRC-arch"="UCSF",
    "UMichMRC"="UMich",
    "UMichMRC-arch"="UMich",
    "UNC"="UNC",
    "UNC-arch"="UNC",
    "UWash_BOLDRegistry"="UWash",
    "UWash_BOLDRegistry-arch"="UWash",
    "Cedars-SinaiP2-arch"="CedarsSinai",
    "Cedars-SinaiP2"="CedarsSinai");

out <- tibble(file=csv_files$file, domain=domain, row_count=rows, schema=s) %>%
    mutate(leading_dir={        
        str_split(file,"/") %>%
            tidymap(function(e) e[3]) %>%
            unlist();
    }) %>%
    mutate(archive = leading_dir == "ARCHIVE") %>%
    mutate(theoretical_model= grepl("TM_",file,fixed=TRUE)) %>%
    mutate(real_leading_dir={
        ald <- str_split(file,"/") %>%
            tidymap(function(e) e[4]) %>%
            unlist();
        ld <- leading_dir;
        ld[leading_dir=="ARCHIVE" %>% na_to_false()] <- ald[leading_dir=="ARCHIVE" %>% na_to_false()];
        ld
    }) %>%
    mutate(institution=site_map[real_leading_dir] %>% unlist() %>% unname()) %>%
    select(-real_leading_dir) %>%
    mutate(minimum_data_set=!is.na(domain)) %>%
    rowwise() %>%
    mutate(file_hash = {
        system(sprintf("md5sum \"%s\"",file), intern=T) %>% str_split(" ",simplify=T) %>% `[[`(1);
    }) %>% ungroup() %>%
    group_by(archive, file_hash) %>%
    mutate(duplicate=row_number()!=1) %>%
    ungroup();

write_csv(out, "derived_data/meta-data.csv");
 

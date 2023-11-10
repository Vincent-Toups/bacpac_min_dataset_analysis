library(tidyverse);
meta_data <- read_csv("derived_data/meta-data.csv") %>% filter(duplicate==F)

data_submitted <- meta_data %>%
    filter(!is.na(domain) & !archive) %>%
    group_by(domain, institution, file) %>%    
    tally() %>%
    rowwise() %>%
    mutate(study={
        d = read_csv(file,n_max=1) %>% pull(STUDYID);
    }) %>%
    ungroup() %>%
    mutate(study=sprintf("%s (%s)", study, institution)) %>%
    filter(!is.na(domain)) %>%
    select(-file,-institution) %>%
    select(-n) %>%
    mutate(dummy=T) %>%
    pivot_wider(names_from = domain, values_from = dummy) %>%
    arrange(apply(is.na((.)), 1, sum)) %>%
    select(study, DM, SC, QS, EX, FT);
print(data_submitted)





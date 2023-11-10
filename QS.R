library(tidyverse);

qs <- read_csv("derived_data/qs-collected.csv") %>%
    select(STUDYID, USUBJID, VISITNUM) %>% distinct();

counts <- read_csv("derived_data/qs-collected.csv") %>% group_by(STUDYID) %>% tally(name="Row Count") %>%
    inner_join(qs %>% select(STUDYID, USUBJID) %>% distinct() %>% group_by(STUDYID) %>% tally(name="Subject Count"),
               by="STUDYID");



visit_count <- qs %>% group_by(STUDYID, USUBJID) %>% tally(name="Visit Count");
avg_visit_count <- visit_count %>% group_by(STUDYID) %>% summarize(`Average Number of Visits`=mean(`Visit Count`));

write_csv(avg_visit_count, "derived_data/avg_visit_counts.csv")

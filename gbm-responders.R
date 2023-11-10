library(tidyverse);
library(gbm);
source("util.R")

eco <- read_csv("derived_data/eco-encoded.csv");
demo <- read_csv("derived_data/demo-encoded.csv");
all_data <- read_csv("derived_data/subject-changes.csv") %>%
    select(`USUBJID`,`Group`,`Visit Count`) %>%
    inner_join(eco,by="USUBJID") %>%
    inner_join(demo, by="USUBJID") %>%
    mutate(improved=`Group`=='Improved') %>%
    select(-`Group`) %>%
    filter(`Visit Count`>8) %>% select(-`Visit Count`);

columns <- names(all_data);
bad_columns <- Filter(function(col_name){
    length(unique(all_data[[col_name]])) < 2;
},columns)
good_columns <- columns[!(columns %in% bad_columns)]


all_data <- all_data %>% select(all_of(good_columns))

f<-improved~.

k = 5;
k <- 5;

fold_ii <- all_data %>% group_by(improved) %>% mutate(fold=(floor(seq(0,0.999,length.out=length(Change))*k))+1) %>% ungroup() %>% pull(fold);

characterization <- do.call(rbind, Map(function(i){
    train_ii <- fold_ii != i#runif(nrow(ex_wide_time)) < 0.75;
    train <- all_data %>% filter(train_ii);
    test <- all_data %>% filter(!train_ii);


    model <- gbm(f, distribution="bernoulli", data=train %>% select(-`USUBJID`),
                 interaction.depth=3, n.trees=300);
    
    roc_info <- roc(predict(model, newdata=test, type='response', n.trees=100),test$improved,pts=seq(0,1,length.out=100)) %>% mutate(fold=i);
},1:k))



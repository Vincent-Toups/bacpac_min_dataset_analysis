library(tidyverse);
library(gbm);

eco <- read_csv("derived_data/eco-encoded.csv");
demo <- read_csv("derived_data/demo-encoded.csv");
data <- read_csv("derived_data/subject-changes.csv") %>%
    select(`Pain Interferene Start`>60) %>%
    select(`USUBJID`,`Group`,`Visit Count`) %>%
    inner_join(eco,by="USUBJID") %>%
    inner_join(demo, by="USUBJID") %>%
    mutate(improved=`Group`=='Improved') %>%
    select(-`Group`) %>%
    filter(`Visit Count`>8) %>% select(-`Visit Count`);

columns <- names(data);
bad_columns <- Filter(function(col_name){
    length(unique(data[[col_name]])) < 2;
},columns)
good_columns <- columns[!(columns %in% bad_columns)]


data <- data %>% select(all_of(good_columns))

f<-improved~.


train_ii <- runif(nrow(data)) < 0.5;
train <- data %>% filter(train_ii);
test <- data %>% filter(!train_ii);

model <- gbm(f, distribution="bernoulli", data=train %>% select(-`USUBJID`),
             interaction.depth=2, n.trees=100);
roc_info <- roc(predict(model, newdata=test, type='response', n.trees=100),test$improved,pts=seq(0,1,length.out=100));
plot_roc(roc_info);

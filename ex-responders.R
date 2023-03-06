library(tidyverse);
library(gbm);
source('util.R');

ex_data <- do.call(rbind,
                   Map(read_csv,
                       read_csv("derived_data/meta-data.csv") %>%
                       filter(domain=="EX" & archive==F) %>%
                       pull(file))) %>% select(-STUDYID,-DOMAIN);

ex_wide_no_time <- pivot_wider(ex_data,
                               id_cols="USUBJID",
                               names_from="EXTRT",
                               values_from="EXCAT",
                               values_fn=function(...) 1,
                               values_fill=0) %>%
    inner_join(read_csv("derived_data/subject-changes.csv"),by="USUBJID") %>%
    filter(`Visit Count` >= 9) %>%
    mutate(improved=1.0*(Change>0.0));

train_ii <- runif(nrow(ex_wide_no_time)) < 0.8;
train <- ex_wide_no_time %>% filter(train_ii);
test <- ex_wide_no_time %>% filter(!train_ii);

f <-  improved ~ factor(`Exercise`)                                +
                        factor(`Mindfulness or meditation or relaxation`) +
                        factor(`NSAIDs`)                                  +
                        factor(`Opioids`)                                 +
                        factor(`Diet or weight loss program`)             +
                        factor(`Non-spinal fusion`)                       +
                        factor(`Therapy or counseling`)                   +
                        factor(`SSRI_SNRI`)                               +
                        factor(`Acupuncture`)                             +
                        factor(`Spinal fusion`)                           +
                        factor(`Gabapentin or pregabalin`)                +
                        factor(`Tricyclic antidepressants`);

model <- gbm(f,
             distribution='bernoulli', data=train, interaction.depth=3);

roc_info <- roc(predict(model, newdata=test, type="response"),test$improved,pts=seq(0,1,length.out=100));
plot_roc(roc_info);

ex_wide_time <- pivot_wider(ex_data,
                               id_cols=c("USUBJID","EXDY"),
                               names_from="EXTRT",
                               values_from="EXCAT",
                               values_fn=function(...) 1,
                            values_fill=0) %>%
    group_by(USUBJID) %>% arrange(EXDY) %>% 
    summarize(`Mindfulness or meditation or relaxation`={
        start_ii <- min(which(`Mindfulness or meditation or relaxation`==1));
        if (start_ii == Inf) {
            -1;
        } else {
            EXDY[[start_ii]];
        }
    },
    `Exercise`={
        start_ii <- min(which(`Exercise`==1));
        if (start_ii == Inf) {
            -1;
        } else {
            EXDY[[start_ii]];
        }
    },
    `NSAIDs`={
            start_ii <- min(which(`NSAIDs`==1));
        if (start_ii == Inf) {
            -1;
        } else {
            EXDY[[start_ii]];
        }
    },
    `Opioids`={
        start_ii <- min(which(`Opioids`==1));
        if (start_ii == Inf) {
            -1;
        } else {
            EXDY[[start_ii]];
        }
    },
    `Diet or weight loss program`={
        start_ii <- min(which(`Diet or weight loss program`==1));
        if (start_ii == Inf) {
            -1;
        } else {
            EXDY[[start_ii]];
        }
    },
    `Non-spinal fusion`={
        start_ii <- min(which(`Non-spinal fusion`==1));
        if (start_ii == Inf) {
            -1;
        } else {
            EXDY[[start_ii]];
        }
    },
    `Therapy or counseling`={
        start_ii <- min(which(`Therapy or counseling`==1));
        if (start_ii == Inf) {
            -1;
        } else {
            EXDY[[start_ii]];
        }
    },
    `SSRI_SNRI`={
        start_ii <- min(which(`SSRI_SNRI`==1));
        if (start_ii == Inf) {
            -1;
        } else {
            EXDY[[start_ii]];
        }
    },
    `Acupuncture`={
        start_ii <- min(which(`Acupuncture`==1));
        if (start_ii == Inf) {
            -1;
        } else {
            EXDY[[start_ii]];
        }
    },
    `Spinal fusion`={
        start_ii <- min(which(`Spinal fusion`==1));
        if (start_ii == Inf) {
            -1;
        } else {
            EXDY[[start_ii]];
        }
    },
    `Gabapentin or pregabalin`={
        start_ii <- min(which(`Gabapentin or pregabalin`==1));
        if (start_ii == Inf) {
            -1;
        } else {
            EXDY[[start_ii]];
        }
    },
    `Tricyclic antidepressants`={
        start_ii <- min(which(`Tricyclic antidepressants`==1));
        if (start_ii == Inf) {
            -1;
        } else {
            EXDY[[start_ii]];
        }
    }) %>% 
    inner_join(read_csv("derived_data/subject-changes.csv"),by="USUBJID") %>%
    filter(`Visit Count` >= 8) %>%
    mutate(improved=1.0*(Change>5.0));

train_ii <- runif(nrow(ex_wide_time)) < 0.7;
train <- ex_wide_time %>% filter(train_ii);
test <- ex_wide_time %>% filter(!train_ii);

f <-  improved ~ (`Exercise`)                                +
                        (`Mindfulness or meditation or relaxation`) +
                        (`NSAIDs`)                                  +
                        (`Opioids`)                                 +
                        (`Diet or weight loss program`)             +
                        (`Non-spinal fusion`)                       +
                        (`Therapy or counseling`)                   +
                        (`SSRI_SNRI`)                               +
                        (`Acupuncture`)                             +
                        (`Spinal fusion`)                           +
                        (`Gabapentin or pregabalin`)                +
                        (`Tricyclic antidepressants`);

model <- gbm(f,
             distribution='bernoulli', data=train, interaction.depth=3,n.trees=100);
roc_info <- roc(predict(model, newdata=test, type="response"),test$improved,pts=seq(0,1,length.out=1000));
p <- plot_roc(roc_info);
ggsave("figures/treatment-model-roc.png");


library(tidyverse);

roc <- function(probs, actual, pts = seq(0,1,length.out=20)){
    once <- function(p){
        prediction <- probs > p;
        positive_ii <- which(actual==1);
        negative_ii <- which(!(actual==1));
        n_negative = length(negative_ii);
        n_positive = length(positive_ii);
        true_positive_rate <- sum(prediction[positive_ii])/n_positive;
        false_positive_rate <- sum(prediction[negative_ii])/n_negative;
        tibble(threshold=p,
               Accuracy=sum(prediction==actual)/length(prediction),
               `True Positive Rate`=true_positive_rate,
               `False Positive Rate`=false_positive_rate);
    }
    do.call(rbind,Map(once, pts)) %>% arrange(`True Positive Rate`);
}

roc_auc <- function(roc_info){
    roc_info <- roc_info %>% arrange(`False Positive Rate`);
    y <- roc_info %>% pull(`True Positive Rate`);
    x <- roc_info %>% pull(`False Positive Rate`);
    xl <- x[1:(length(x)-1)];
    xr <- x[2:length(x)];

    yl <- y[1:(length(y)-1)];
    yr <- y[2:length(y)];

    sum((xr-xl)*(1/2)*(yl+yr));    
}


plot_roc <- function(roc_out){
    ggplot(roc_out %>% arrange(`False Positive Rate`), aes(`False Positive Rate`, `True Positive Rate`)) +
        geom_line() +
        geom_line(data=tibble(x=c(0,1),y=c(0,1)),
                  aes(x,y),linetype="dashed",color="grey") +
        labs(title=sprintf("AUC: ~%0.2f", roc_auc(roc_out)));
                                                                                                                                  
}


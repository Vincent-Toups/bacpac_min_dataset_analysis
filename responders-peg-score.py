import math
import pandas as pd
import numpy as np
import polars as pl
from polars import col as c, lit as l
import keras
from keras import layers, backend
from numpy.random import seed
from tensorflow.random import set_seed as tf_set_seed
from plotnine import *
from io import StringIO
import util as u
from scipy.signal import savgol_filter

seed(1000);
tf_set_seed(1000);

def ungroup(dataframes):
    return pl.concat(dataframes, how='vertical');

meta_data = (pl.read_csv("derived_data/meta-data.csv")
                            .filter(pl.col("domain")=="QS")
                            .filter(pl.col("archive")=="false"));

columns = u.calc_shared_columns(list(meta_data["schema"]));
qs = pl.concat([(pl.read_csv(file, parse_dates=True).select(columns)
                 .with_columns(c('VISITNUM').cast(pl.Int64).alias('VISITNUM'))) for file in meta_data["file"]]);
peg_score = (qs.filter(c('QSTESTCD')=='PEGSCORE')
                     .select(['USUBJID','VISITNUM','QSSTRESN','QSDTC'])
                     .with_columns([c('VISITNUM').alias('Visit Number'),
                                    c('QSSTRESN').alias('Peg Score'),
                                    c('QSDTC').alias('Visit Date')])
                     .drop(['VISITNUM','QSSTRESN','QSDTC']));

week_counts = (peg_score
               .groupby('USUBJID')
               .count()
               .with_columns(c('count').alias('Visit Count'))
               .drop('count'));



sorted_visit_numbers = [str(vn) for vn in list(peg_score.groupby('Visit Number').count().sort('Visit Number')['Visit Number'])];
pain_int_with_nulls = (peg_score
                       .drop('Visit Date')
                       .pivot(index='USUBJID',values='Peg Score',columns='Visit Number')
                       .select(['USUBJID']+sorted_visit_numbers)
                       .melt(id_vars='USUBJID',variable_name='Visit Number',value_name='Peg Score')
                       .with_columns(c('Visit Number').cast(pl.Int64).alias('Visit Number')));
pile = [(df[1]
     .sort('Visit Number')
     .interpolate()
     .with_columns(c('Peg Score')
                   .forward_fill()
                   .alias('Peg Score'))
     .with_columns(c('Peg Score')
                   .ewm_mean(alpha=0.2)
                   .alias('Peg Score (Smoothed)'))) for df in pain_int_with_nulls.groupby('USUBJID')];

peg_score = ungroup(pile);

peg_score = peg_score.join(week_counts,on="USUBJID",how="inner");

early_pi = (peg_score
            .filter(c('Visit Number')<=4)
            .groupby('USUBJID')
            .agg(c('Peg Score').mean().alias('Peg Score Start')))
later_pi = (peg_score
            .filter(c('Visit Number')>=38)
            .groupby('USUBJID')
            .agg(c('Peg Score').mean().alias('Peg Score End')));

thresh = 0.4;
change = (early_pi
          .join(later_pi,on="USUBJID",how="inner").join(week_counts,on="USUBJID",how="inner")
          .with_columns((c('Peg Score Start')-c('Peg Score End')).alias('Change'))
          .with_columns(pl.when(c('Change')>thresh)
                        .then(pl.lit('Improved'))
                        .when(c('Change')>=-thresh)
                        .then(pl.lit('Static'))
                        .when(c('Change')<-thresh)
                        .then(pl.lit('Worsened'))
                        .otherwise('???')
                        .alias('Group')))

peg_score = peg_score.join(change
                                           .drop('Visit Count'), on="USUBJID", how="inner");

((ggplot(change.filter(c('Visit Count')>=9)
         .to_pandas(),aes('Change'))+
  geom_histogram())).save("figures/change-distribution.png");
 

((ggplot(peg_score
         .with_columns(pl.when(c('Peg Score Start')>6).then(pl.lit(0.75)).otherwise(pl.lit(0.25)).alias('Initial Pain High'))
         .to_pandas(), aes('Visit Number','Peg Score (Smoothed)'))+
 geom_line(aes(group='USUBJID',color='Group',alpha='Initial Pain High')))
.save("figures/ts-peg-score.png"))

(peg_score
 .sort('Visit Number')
 .groupby('USUBJID')
 .agg([c('Visit Number').alias('Visit Number'),
       c('Peg Score').alias('Peg Score'),
       c('Visit Number').count().alias('Samples')])
 .groupby('Samples').count().sort('Samples'))

pi_initial = peg_score.groupby('USUBJID')

change.write_csv("derived_data/subject-changes-peg-score.csv");

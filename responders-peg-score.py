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


def coerce_to_string(df, column_name):
    return df.with_columns(pl.col(column_name).cast(str).alias(column_name))

def replace_values_with_none(df, column_name, values=['NA', '', '.']):
    return df.with_columns(pl.when(pl.col(column_name).is_in(values)).then(None).otherwise(pl.col(column_name)).alias(column_name))

def cast_to_float(df, column_name):
    return df.with_columns(pl.col(column_name).cast(pl.Float64).alias(column_name))

def trim_whitespace(df, column_name):
    '''
    Trims extraneous whitespace from the specified column of the dataframe.

    Parameters:
    - df: polars DataFrame
    - column_name: str, the column to trim

    Returns:
    - A new DataFrame with the whitespace-trimmed column
    '''

    return df.with_column(pl.col(column_name).str.strip().alias(column_name))

 
columns = u.calc_shared_columns(list(meta_data["schema"]));
qs = pl.concat([(pl.read_csv(file, parse_dates=True).filter(c('QSTESTCD')=='PEGSCORE').select(columns)
                 .pipe(coerce_to_string, 'QSSTRESN')
                 .pipe(replace_values_with_none, 'QSSTRESN')
                 .pipe(trim_whitespace,'QSSTRESN')
                 .pipe(replace_values_with_none, 'QSSTRESN')
                 .pipe(cast_to_float, 'QSSTRESN')
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



sorted_visit_numbers = [str(vn) for vn in list(peg_score.groupby('Visit Number').count().sort('Visit Number')['Visit Number']) if str(vn) != 'None'];

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

peg_score = (peg_score.join(change
                           .drop('Visit Count'), on="USUBJID", how="inner")
             .filter(c('Group') != '???'))

((ggplot(change.filter(c('Visit Count')>=6)
         .to_pandas(),aes('Change'))+
  geom_histogram())).save("figures/change-distribution.png");
 

((ggplot(peg_score
         .with_columns(pl.when(c('Peg Score Start')>7).then(pl.lit(0.75)).otherwise(pl.lit(0.25)).alias('Initial Pain High'))
         .to_pandas(), aes('Visit Number','Peg Score (Smoothed)'))+
 geom_line(aes(group='USUBJID',color='Group',alpha='Initial Pain High'))+
  ylim(0, 10) +
 facet_wrap("Group",nrow=3))
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

peg_score.write_csv("derived_data/peg_score_ts.csv");

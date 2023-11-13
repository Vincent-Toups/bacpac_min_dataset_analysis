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
from isoduration import parse_duration
import isoduration

def duration_to_hours(dur):
    hours = float(dur.date.years)*8765.999;
    hours = hours + float(dur.date.months)*730.5
    hours = hours + float(dur.date.weeks)*168;
    hours = hours + float(dur.date.days)*24;
    hours = hours + float(dur.time.hours);
    hours = hours + float(dur.time.minutes)/60.0;
    hours = hours + float(dur.time.seconds)/3600.00;
    return hours;

def handle_qsstresn_conversion(item):
    """Uniformly convert values to floating point numbers."""
    n = None;
    try:
        n = float(item);
        return n;
    except ValueError:
        pass
    try:
        n = duration_to_hours(parse_duration(item));
        return n;
    except isoduration.parser.exceptions.DurationParsingException:
        pass
    if not (item == "." or item.strip() == "" or item.strip() == "NA"):
        print(f"Weird value in QSSTRESN {item}");
        return None;
    else:
        return None;
    return None;

seed(1000);
tf_set_seed(1000);

def ungroup(dataframes):
    return pl.concat(dataframes, how='vertical');

meta_data = (pl.read_csv("derived_data/meta-data.csv")
                            .filter(pl.col("domain")=="QS")
                            .filter(pl.col("archive")=="false"));

columns = u.calc_shared_columns(list(meta_data["schema"]));
qs = pl.concat([(pl.read_csv(file, parse_dates=True).select(columns)
                 .with_columns(c('VISITNUM').cast(pl.Int64).alias('VISITNUM'))
                 .with_columns(c('QSSTRESN')
                               .cast(str)
                               .apply(handle_qsstresn_conversion)
                               .alias('QSSTRESN')))
                 for file in meta_data["file"]]);

qs.write_csv("derived_data/qs-collected.csv")

study_counts = qs.groupby('STUDYID').count().with_columns(c('count').alias('Row Count')).drop('count');
subject_counts = (qs
                  .groupby(['STUDYID','USUBJID'])
                  .count()
                  .drop('count')
                  .groupby('STUDYID')
                  .count()
                  .with_columns(c('count').alias('Subject Count'))
                  .drop('count'));
counts = study_counts.join(subject_counts,on="STUDYID",how="inner");
 


pain_interference = (qs.filter(c('QSTESTCD')=='PRPI4AT')
                     .select(['USUBJID','VISITNUM','QSSTRESN','QSDTC'])
                     .with_columns([c('VISITNUM').alias('Visit Number'),
                                    c('QSSTRESN').alias('Pain Interference'),
                                    c('QSDTC').alias('Visit Date')])
                     .drop(['VISITNUM','QSSTRESN','QSDTC']));

pain_interference = pain_interference.filter(c('Visit Number')!=None);

week_counts = (pain_interference
               .groupby('USUBJID')
               .count()
               .with_columns(c('count').alias('Visit Count'))
               .drop('count'));




sorted_visit_numbers = [str(vn) for vn in list(pain_interference.groupby('Visit Number').count().sort('Visit Number')['Visit Number'])];
pain_int_with_nulls = (pain_interference
                       .drop('Visit Date')
                       .pivot(index='USUBJID',values='Pain Interference',columns='Visit Number')
                       .select(['USUBJID']+sorted_visit_numbers)
                       .melt(id_vars='USUBJID',variable_name='Visit Number',value_name='Pain Interference')
                       .with_columns(c('Visit Number').cast(pl.Int64).alias('Visit Number')));
pile = [(df[1]
     .sort('Visit Number')
     .interpolate()
     .with_columns(c('Pain Interference')
                   .forward_fill()
                   .alias('Pain Interference'))
     .with_columns(c('Pain Interference')
                   .ewm_mean(alpha=0.4)
                   .alias('Pain Interference (Smoothed)'))) for df in pain_int_with_nulls.groupby('USUBJID')];

pain_interference = ungroup(pile);

pain_interference = pain_interference.join(week_counts,on="USUBJID",how="inner");
pain_interference.write_csv("derived_data/pain-interference-smoothed.csv");


early_pi = (pain_interference
            .filter(c('Visit Number')<=4)
            .groupby('USUBJID')
            .agg(c('Pain Interference').mean().alias('Pain Interference Start')))
later_pi = (pain_interference
            .filter(c('Visit Number')>=38)
            .groupby('USUBJID')
            .agg(c('Pain Interference').mean().alias('Pain Interference End')));

thresh = 5;
change = (early_pi
          .join(later_pi,on="USUBJID",how="inner").join(week_counts,on="USUBJID",how="inner")
          .with_columns((c('Pain Interference Start')-c('Pain Interference End')).alias('Change'))
          .with_columns(pl.when(c('Change')>thresh)
                        .then(pl.lit('Improved'))
                        .when(c('Change')>=-thresh)
                        .then(pl.lit('Static'))
                        .when(c('Change')<-thresh)
                        .then(pl.lit('Worsened'))
                        .otherwise('???')
                        .alias('Group')))

pain_interference = pain_interference.join(change
                                           .drop('Visit Count'), on="USUBJID", how="inner");

((ggplot(change.filter(c('Visit Count')>=9)
         .to_pandas(),aes('Change'))+
  labs(x="Delta Pain Interference (Start-End)")+
  geom_histogram())).save("figures/change-distribution.png");
 

# ((ggplot(pain_interference.filter(c('Visit Count')>=9).to_pandas(), aes('Visit Number','Pain Interference (Smoothed)'))+
#   geom_line(aes(group='USUBJID',color='Group'),alpha=0.3)+
#   geom_line(data=pain_interference
#             .filter(c('Group')=="Improved")
#             .filter(c('Visit Count')>=9)
#             .to_pandas(), mapping=aes('Visit Number','Pain Interference (Smoothed)',group="USUBJID"),color="red",alpha=1,size=1) +
#   facet_wrap("Group",nrow=3)).save("figures/ts-pain-interference.png"))

((ggplot(pain_interference.filter(c('Visit Count')>=9).to_pandas(), aes('Visit Number','Pain Interference (Smoothed)'))+
  geom_line(aes(group='USUBJID',color='Group'),alpha=0.3)+
  facet_wrap("Group",nrow=3)).save("figures/ts-pain-interference.png"))
 
(pain_interference
 .sort('Visit Number')
 .groupby('USUBJID')
 .agg([c('Visit Number').alias('Visit Number'),
       c('Pain Interference').alias('Pain Interference'),
       c('Visit Number').count().alias('Samples')])
 .groupby('Samples').count().sort('Samples'))

pi_initial = pain_interference.groupby('USUBJID')

change.write_csv("derived_data/subject-changes.csv");


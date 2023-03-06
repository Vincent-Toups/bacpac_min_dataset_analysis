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

meta_data = (pl.read_csv("derived_data/meta-data.csv")
                            .filter(pl.col("domain")=="EX")
                            .filter(pl.col("archive")=="false"));
columns = u.calc_shared_columns(list(meta_data["schema"]));
ex = pl.concat([(pl.read_csv(file, parse_dates=True).select(columns))
                for file in meta_data["file"]]);

study_counts = ex.groupby('STUDYID').count().with_columns(c('count').alias('Row Count')).drop('count');
subject_counts = (ex
                  .groupby(['STUDYID','USUBJID'])
                  .count()
                  .drop('count')
                  .groupby('STUDYID')
                  .count()
                  .with_columns(c('count').alias('Subject Count'))
                  .drop('count'));
counts = study_counts.join(subject_counts,on="STUDYID",how="inner");

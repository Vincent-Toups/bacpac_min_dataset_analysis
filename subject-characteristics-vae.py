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

seed(1000);
tf_set_seed(1000);

meta_data = (pl.read_csv("derived_data/meta-data.csv")
                            .filter(pl.col("domain")=="SC")
                            .filter(pl.col("archive")=="false"));


shared_columns = u.calc_shared_columns(meta_data["schema"])

sc = pl.concat([(pl.read_csv(file).select(shared_columns)
                  .with_columns(pl.col('SCSTRESN').cast(str).alias('SCSTRESN'))
                  .with_columns(pl.when(c('SCSTRESN')=="NA").then(None).otherwise(c('SCSTRESN'))
                                  .alias('SCSTRESN'))
                  .with_columns(pl.when(c('SCSTRESN')==".").then(None).otherwise(c('SCSTRESN'))
                                  .alias('SCSTRESN'))
                  .with_columns(c('SCSTRESN').cast(pl.Float64).alias('SCSTRESN'))) for file in meta_data["file"]]);

studycounts = sc.groupby('STUDYID').count().with_columns(c('count').alias('Row Count')).drop('count');
subject_counts = sc.groupby(['STUDYID','USUBJID']).count().drop('count').groupby('STUDYID').count().with_columns(c('count').alias('Subject Count')).drop('count');
counts = studycounts.join(subject_counts,on="STUDYID",how="inner");


focus = sc.select(['SCTESTCD','SCTEST','SCSTRESC','USUBJID']);
wide = focus.select(['SCTESTCD','SCSTRESC','USUBJID']).pivot(values="SCSTRESC", index="USUBJID", columns="SCTESTCD")
test_info = focus.select(['SCTESTCD', 'SCTEST']).unique();

encodings = {
    'EDLEVEL':{'Did not complete secondary school or less than high school':1,
               'Doctoral or postgraduate education':6,
               '':-1,
               "Associate's or technical degree complete":4,
               None:-1,
               'Some secondary school or high school education':2,
               'High school or secondary school degree complete':3,
               'College or baccalaureate degree complete':5},
    'EMPSTAT':{
        None: -1,
        '':-1,
        'Not employed':0,
        'Part-time employment':1,
        'Full-time employment':2
    },
    'BPSURGTM':{
        None:-1,
        '':-1,
        'Does Not Apply':-1,
        'Less than 6 months':0,
        'More than 6 months but less than 1 year ago':1,
        'Between 1 and 2 years ago':2,
        'More than 2 years ago':3
    },
    'BPSURGSF':{
        None:-1,
        '':-1,
        'Does not apply':0,
        'Not sure':-1,
        'No':0,
        'Yes':1
    },
    'HHINCOME':{
        '$10,000 to $24,999':10000,
        'Prefer not to answer':-1,
        '$100,000 to $149,999':100000,
        '':-1,
        '$50,000 to $74,999':50000,
        '$35,000 to $49,999':35000,
        'Less than $10,000':0,
        '$200,000 or more':200000,
        '$150,000 to $199,999':150000,
        '$75,000 to $99,999':75000,
        '$25,000 to $34,999':25000
    }
}

encoding_meta = pl.read_csv(StringIO("""
SCTESTCD,SCTEST,Mode
HHNUM,Number of People Living in Household,continuous
PAINDUR,Duration of Type of Pain for which Enrolled in Study (Months),continuous
BPDISAB,Ever Applied for or Received Disability Insurance for Pain,categorical
BPLWSUIT,Ever Involved in Lawsuit or Legal Claim Related to Back Problem,categorical
BPMORE,Low Back Pain More Severe than Pain in Other Parts of Body,categorical
BPSURG,Ever Had Low Back Operation,categorical
BPUNEMP,Ever Unemployed for 1 or More Months Due to Low Back Pain,categorical
BPWKCOMP,Ever Filed or Awarded Workers Comp for Back Problem,categorical
EDLEVEL,Highest Level of Education Completed,pseudo-categorical
EMPSTAT,Current Employment Status,pseudo-categorical
GENIDENT,Gender Identity,categorical
HEIGHT,Height at Baseline,continuous
HHINCOME,Annual Household Income from All Sources,pseudo-categorical
MARISTAT,Current Relationship Status,categorical
WEIGHT,Weight at Baseline,continuous
BPSURGSF,Any Back Operations Involve a Spinal Fusion,pseudo-categorical
BPSURGTM,When was Last Back Operation,pseudo-categorical
"""));
 
def spec_has_special(spec):
    for k,v in spec.items():
        if v == -1:
            return True
    return False;

def ohe(df, col):
    df = df.with_columns(pl
                         .when(pl.col(col)==None)
                         .then(pl.lit('None'))
                         .otherwise(pl.col(col))
                         .alias(col));
    df = df.with_columns(pl
                         .when(pl.col(col).str.strip()=='')
                         .then(pl.lit('None'))
                         .otherwise(pl.col(col))
                         .alias(col));
    for v in set(df[col]):
        df = df.with_columns(pl.when(pl.col(col)==v).then(1).otherwise(0).alias(f"{col}_{v}"));
    return df.drop(col);
                         
def ohe_pseudo(df, col, spec):
    for k, v in spec.items():
        df = df.with_columns(pl
                             .when(pl.col(col)==k)
                             .then(pl.lit(v))
                             .otherwise(pl.col(col))
                             .alias(col));
    df = df.with_columns(pl.col(col).cast(pl.Float64).alias(col));
    mn = df[col].min();
    mx = df[col].max();
    df = (df.with_columns(((pl.col(col)-mn)/(mx-mn)).alias(col))
          .with_columns(pl.when(pl.col(col)==0).then(1).otherwise(0).alias(f"{col}_missing")));
    return df;



def rescale_col(df, col):
    df = (df
          .with_columns(pl.when(c(col).str.strip()=='').then(pl.lit(None)).otherwise(c(col)).alias(col))
          .with_columns(pl.when(c(col) == None).then(pl.lit(1)).otherwise(pl.lit(0)).alias(f"{col}_missing"))
          .with_columns(pl.when(c(col) == None).then(pl.lit("-1")).otherwise(c(col)).alias(col))
          .with_columns(c(col).cast(pl.Float64).alias(col))
          .with_columns(((c(col)-c(col).min())/(c(col).max()-c(col).min())).alias(col)));
    missing_count = df[f"{col}_missing"].sum();
    if missing_count == 0:
        df = df.drop(f"{col}_missing");
    return df

def df_cols_to_dict(df, key, value):
    keys = df[key];
    values = df[value];
    out = dict();
    for i in range(len(keys)):
        out[keys[i]] = values[i];
    return out;

def prep_for_nn(df, cols, spec, encodings):
    col_encoding_type = df_cols_to_dict(spec,'SCTESTCD','Mode');
    for col in cols:
        print(col)
        mode = col_encoding_type[col];
        print(f'Working on {col} ({mode})');
        if mode == 'continuous':
            df = rescale_col(df, col);
        elif mode == 'categorical':
            df = ohe(df, col);
        elif mode == 'pseudo-categorical':
            df = ohe_pseudo(df, col, encodings[col]);
        else:
            raise(ValueError(f'Column {col} encoding type has to be categorical, pseudo-categorical or continuous, but {mode}.'));
    return df;

def collect_column_null_info(df):
    null_count = [];
    for c in df.columns:
        x = list(df[c]);
        n = 0;
        for item in x:
            if item == None or item.strip() == '':
                n = n + 1;
        null_count.append(n);
    return pl.DataFrame({"column":df.columns, "null_count":null_count});

def fix_missing(df, col):
    return (wide
            .with_columns(pl
                         .when((c(col)==".") | (c(col).str.strip()==""))
                          .then(None)
                          .otherwise(c(col))
                          .alias(col)));

wide = fix_missing(wide,'HHNUM');
wide = fix_missing(wide,'PAINDUR');
wide = fix_missing(wide,'HEIGHT');
wide = fix_missing(wide,'WEIGHT');

encoded = pl.from_pandas(prep_for_nn(wide, list(encoding_meta['SCTESTCD']), encoding_meta, encodings).to_pandas().dropna())

encoded.write_csv("derived_data/sc-encoded.csv");

def build_vae(n_input=54,
              n_intermediate=3,
              encoded_dimension=2,
              intermediate_size=25):

    input = keras.Input(shape=(n_input,));
    e = layers.Dropout(0.1, input_shape=(n_input,))(input);
    e = layers.Dense(intermediate_size, activation='relu')(e);
    for i in range(n_intermediate-1):
        e = layers.Dense(intermediate_size, activation='relu')(e);

    mu_layer = layers.Dense(encoded_dimension, name="encoder_mu")(e);
    log_var_layer = layers.Dense(encoded_dimension, name="encoder_log_var")(e);

    def sampler(mu_log_var):
        mu, log_var = mu_log_var;
        eps = keras.backend.random_normal(keras.backend.shape(mu), mean=0.0, stddev=1.0)
        sample = mu + backend.exp(log_var/2) * eps
        return sample

    encoder_output = layers.Lambda(sampler, name="encoder_output")([mu_layer, log_var_layer])

    d = layers.Dense(intermediate_size, activation='relu')(encoder_output);
    for i in range(n_intermediate-1):
        d = layers.Dense(intermediate_size, activation='relu')(d);

    d = layers.Dense(n_input, activation='linear')(d);

    ae = keras.Model(input, d);
    encoder = keras.Model(input, encoder_output);
    ae.compile(optimizer='adam', loss='mean_squared_error');

    return (ae,encoder)

(ae, enc) = build_vae();

ae.fit(encoded.drop('USUBJID').to_numpy(),
       encoded.drop('USUBJID').to_numpy(),
       batch_size=100, epochs=200);

project = (pl.
           from_pandas(pd.
                       DataFrame(enc.
                                 predict(encoded.
                                         drop('USUBJID').
                                         to_numpy()),columns=['E1','E2'])).
           with_columns(encoded['USUBJID'])
           .join(sc.select(['USUBJID','STUDYID']).unique(),on="USUBJID",how="inner"));

by_study = (ggplot(project.to_pandas(), aes("E1","E2"))+geom_point(aes(color="STUDYID"),size=3,alpha=0.3));
by_study.save("figures/sc_by_study.png");

by_study = (ggplot(project.to_pandas(), aes("E1","E2"))+geom_point(aes(color="STUDYID"),size=3,alpha=0.3)+facet_wrap("STUDYID"));
by_study.save("figures/sc_by_study_facet.png");



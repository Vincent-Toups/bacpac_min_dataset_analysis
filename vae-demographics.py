import math
import pandas as pd
import numpy as np
import polars as pl
from polars import col as c
from polars import lit as l
import keras
from keras import layers, backend
from numpy.random import seed
from tensorflow.random import set_seed as tf_set_seed
from plotnine import *

seed(1000);
tf_set_seed(1000);

def ohe_columns(df, columns):
    for column in columns:
        unique_values = list(set(df[column]));
        for item in unique_values:
            if item == None:
                item = "None";
            df = df.with_columns(((pl.col(column)==item)*1.0).alias(column+'_'+item));
    return df.drop(columns);

def keyfun_group_count(s):
    if s.split(" ")[0] == "Other":
        return -1;
    return int(s.split("(")[1].split(")")[0])

def order_category_column(pdf, colname, keyfun=lambda x,y: x < y):
    
    labels = sorted(list(set(pdf[colname])),key=keyfun,reverse=True);
    cc = pd.Categorical(values=pdf[colname],
                        categories=labels,
                        ordered=True)
    pdf[colname] = cc;
    return pdf;

def count_and_auto_other(df, colname, new_column_name, threshold):
    counts = (df
              .groupby(colname)
              .count()
              .with_columns(pl
                            .when(c('count')<threshold)
                            .then(pl.lit('Other'))
                            .otherwise(c(colname))
                            .alias(new_column_name)))
    return (counts
            .groupby(new_column_name)
            .agg(pl.col("count")
                 .sum())
            .join(counts.drop("count"), on=new_column_name, how="inner")
            .with_columns((pl.col(new_column_name)+
                           pl.lit(" (")+
                           pl.col("count").cast(str)+
                           pl.lit(")")).alias(new_column_name)));


add_label_order = lambda df: order_category_column(df,
                                                   'Gender, Race, Ethnicity (Count)',
                                                   keyfun=keyfun_group_count);


meta_data = (pl.read_csv("derived_data/meta-data.csv")
                            .filter(pl.col("domain")=="DM")
                            .filter(pl.col("archive")=="false"));



demographics = pl.concat([pl.read_csv(file).select(['AGE',
                                                    'BRTHDTC',
                                                    'DOMAIN',
                                                    'ETHNIC',
                                                    'RACE',
                                                    'RACEMULT',
                                                    'RFPENDTC',
                                                    'RFSTDTC',
                                                    'SEX',
                                                    'STUDYID',
                                                    'USUBJID']) for file in meta_data["file"]]);
demographics = (demographics.with_columns(pl.when(pl.col(pl.Utf8).is_null())
                .then("Not reported")
                .otherwise(pl.col(pl.Utf8))
                .keep_name())
                .filter(pl.col('AGE')!=None));

to_encode = demographics.select(['SEX','ETHNIC','RACE']).unique();



demo_ohe = ohe_columns(demographics, ['SEX','ETHNIC','RACE']);
for_tags = demographics.with_columns((pl.col('SEX')+", "+pl.col('RACE')+", "+pl.col('ETHNIC')).alias('tag')).select(['USUBJID','tag']);
tag_counts = for_tags.groupby("tag").agg([pl.count()]).to_pandas().sort_values('count',ascending=False);
for_tags = (for_tags
            .join(pl.from_pandas(tag_counts),on="tag",how="inner")
            .with_columns(pl.when(pl.col('count')>=15).then(pl.col('tag')).otherwise(pl.lit('Other')).alias('Gender, Race, Ethnicity')));

other_count = for_tags.filter(pl.col('Gender, Race, Ethnicity')=="Other").shape[0];
for_tags = (for_tags
            .with_columns((pl.col('Gender, Race, Ethnicity') + pl.lit(' (') +
                          pl.when(pl.col('Gender, Race, Ethnicity')=="Other").then(pl.lit(other_count)).otherwise(pl.col('count').cast(str)) +
                          pl.lit(')')).alias('Gender, Race, Ethnicity (Count)')));
 
tag_cat = pd.Categorical(values=tag_counts['tag'], categories=tag_counts['tag'], ordered=True);

demo_prepped = demo_ohe.with_columns((pl.col('AGE')*1.0).alias('AGE')).select(['USUBJID',
                                                                               'STUDYID',
                                                                               'AGE',
                                                                             'SEX_Intersex',
                                                                             'SEX_Female',
                                                                             'SEX_Male',
                                                                             'ETHNIC_Hispanic or Latino',
                                                                             'ETHNIC_Not reported',
                                                                             'ETHNIC_Not Hispanic or Latino',
                                                                             'RACE_White',
                                                                             'RACE_Unknown',
                                                                             'RACE_Asian',
                                                                             'RACE_Native Hawaiian or Pacific Islander',
                                                                             'RACE_Black or African American',
                                                                             'RACE_Multiple',
                                                                             'RACE_American Indian or Alaska Native',
                                                                             'RACE_Not reported']);
min_age = demo_prepped["AGE"].min();
max_age = demo_prepped["AGE"].max();
demo_prepped = (demo_prepped                
                .with_columns(((pl.col('AGE')-min_age)/(max_age-min_age)).alias('AGE')))
classes = demo_prepped.drop("AGE").unique().with_row_count(name="class");

def build_vae(n_input=15,
              n_intermediate=2,
              encoded_dimension=2,
              intermediate_size=14):

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

demo_prepped.write_csv("derived_data/demo-encoded.csv");

ae.fit(demo_prepped.drop(['USUBJID','STUDYID']).to_numpy(),
       demo_prepped.drop(['USUBJID','STUDYID']).to_numpy(),
       batch_size=100, epochs=100);

age_group = (demographics.select(['USUBJID','AGE'])
             .with_columns(pl
                           .when(pl.col('AGE').is_between(18,29))
                           .then('18-29')
                           .when(pl.col('AGE').is_between(30,49))
                           .then('30-49')
                           .when(pl.col('AGE').is_between(50,69))
                           .then('50-69')
                           .when(pl.col('AGE')>=70)
                           .then('70 or above').alias('Age Group')))

projection = (pd.DataFrame(enc.predict(demo_prepped.drop(['USUBJID','STUDYID']).to_numpy()), columns=["E1","E2"])
              .eval("USUBJID=@demo_prepped['USUBJID']")
              .eval("STUDYID=@demo_prepped['STUDYID']"));
studyid_labels = count_and_auto_other(demographics, 'STUDYID', 'STUDYID (Count)',-1)
projection = (pl
              .from_pandas(projection)
              .join(age_group, on="USUBJID", how="inner")
              .join(for_tags, on="USUBJID", how="inner")
              .join(studyid_labels,on="STUDYID", how="inner")
              .with_columns([c('E1')+np.random.normal(0,0.35,projection.shape[0]),
                             c('E2')+np.random.normal(0,0.35,projection.shape[0])])
              .to_pandas())
projection = order_category_column(projection,
                                   'Gender, Race, Ethnicity (Count)',
                                   keyfun_group_count);
projection = order_category_column(projection,
                                   'STUDYID (Count)',
                                   keyfun_group_count);




              
p = (ggplot(projection, aes("E1","E2")) + geom_point(aes(fill="Gender, Race, Ethnicity (Count)",size="Age Group"),alpha=0.4,color="black",stroke=0.75))
p.save("figures/race-ethnicity-projection.png");

p = (ggplot(projection, aes("E1","E2")) + geom_point(aes(fill="STUDYID (Count)"),alpha=0.2,color='black',stroke=0.75,size=4))
p.save("figures/race-ethnicity-projection-studyid.png");

p = (ggplot(projection, aes("E1","E2")) + geom_point(aes(fill="STUDYID (Count)"),alpha=0.2,color='black',stroke=0.75,size=4) + facet_wrap('STUDYID (Count)'))
p.save("figures/race-ethnicity-projection-studyid-faceted.png");


projection_ex = pl.from_pandas(projection).join(pl.read_csv("derived_data/subject-changes.csv"),
                                on="USUBJID",
                                how="inner");


p = (ggplot(projection_ex
            .filter(c('Visit Count')>=9)
            .join(age_group,on="USUBJID",how="inner")
            .to_pandas(), aes("E1","E2")) +
     geom_point(aes(fill="Gender, Race, Ethnicity (Count)",size="Age Group"),alpha=0.4,color="black",stroke=0.75) +
     facet_wrap("Group"))
p.save("figures/race-ethnicity-responders.png");

proj4outcomes = (projection_ex
            .with_columns(c('Change').abs().alias('Abs. Change'))
            .with_columns((c('Abs. Change').max()-c('Abs. Change')).alias('alpha'))
            .filter(c('Visit Count')>=9)
            .join(age_group,on="USUBJID",how="inner"));

p = (ggplot(proj4outcomes.to_pandas(), aes("E1","E2")) +
     geom_point(aes(fill="Change",size="Age Group", alpha="alpha"),color="black",stroke=0.75))
p.save("figures/race-ethnicity-responders-continuous.png");

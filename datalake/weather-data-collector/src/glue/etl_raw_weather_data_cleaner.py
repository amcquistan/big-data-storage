import logging
import sys

from awsglue.context import GlueContext
from awsglue.dynamicframe import DynamicFrame
from awsglue.utils import getResolvedOptions

import numpy as np
import pandas as pd

from pyspark import SparkContext
from pyspark.sql import functions as F
from pyspark.sql.session import SparkSession
from pyspark.sql.types import FloatType, StringType, IntegerType, DateType


logger = logging.getLogger()
logger.setLevel(logging.INFO)

expected_args = ["s3_bucket", "glue_database", "rawweather_table", "cleanweather_table"]
args = getResolvedOptions(sys.argv, expected_args)

glue_db = args['glue_database']
s3_bkt = args['s3_bucket']
rawweather_tbl = args['rawweather_table']
cleanweather_tbl = args['cleanweather_table']
output_s3_path = "s3://{}/{}".format(s3_bkt, cleanweather_tbl)

logger.info({
  'glue_database': glue_db,
  's3_bucket': s3_bkt,
  'rawweather_table': rawweather_tbl,
  'output_s3_path': output_s3_path
})


spark = SparkSession(SparkContext.getOrCreate())
glue_ctx = GlueContext(SparkContext.getOrCreate())

raw_dyf = glue_ctx.create_dynamic_frame.from_catalog(database=glue_db, table_name=rawweather_tbl)


def process_hourly(hours, key, fn):
    nums = []
    for hr in hours:
        if hr[key]:
            try:
                num = float(hr[key])
                if pd.notnull(num):
                    nums.append(num)
            except Exception as e:
                logger.error({
                    "error": str(e),
                    "message": "error converting {} to float".format(hr[key])
                })
                raise e
    if nums:
        return float(fn(nums))

    return np.nan


avg_humidity = F.udf(lambda hours: process_hourly(hours, 'humidity', np.mean), FloatType())
avg_pressure = F.udf(lambda hours: process_hourly(hours, 'pressure', np.mean), FloatType())

min_humidity = F.udf(lambda hours: process_hourly(hours, 'humidity', min), FloatType())
min_pressure = F.udf(lambda hours: process_hourly(hours, 'pressure', min), FloatType())

max_humidity = F.udf(lambda hours: process_hourly(hours, 'humidity', max), FloatType())
max_pressure = F.udf(lambda hours: process_hourly(hours, 'humidity', max), FloatType())

total_precipMM = F.udf(lambda hours: process_hourly(hours, 'precipMM', sum), FloatType())

clean_df = raw_dyf.toDF().withColumn(
            'avgHumidity',  avg_humidity('hourly')
        ).withColumn(
            'avgPressure', avg_pressure('hourly')
        ).withColumn(
            'minHumidity',  min_humidity('hourly')
        ).withColumn(
            'minPressure', min_pressure('hourly')
        ).withColumn(
            'maxHumidity', max_humidity('hourly')
        ).withColumn(
            'maxPressure', max_pressure('hourly')
        ).withColumn(
            'totalPrecipMM', total_precipMM('hourly')
        ).withColumn(
            'maxtempF', F.col('maxtempF').cast(FloatType())
        ).withColumn(
            'mintempF', F.col('mintempF').cast(FloatType())
        ).withColumn(
            'avgtempF', F.col('avgtempF').cast(FloatType())
        ).withColumn(
            'totalSnow_cm', F.col('totalSnow_cm').cast(FloatType())
        ).withColumn(
            'sunHour', F.col('sunHour').cast(FloatType())
        ).withColumn(
            'uvIndex', F.col('uvIndex').cast(IntegerType())
        ).withColumn(
            'date', F.col('date').cast(DateType())
        ).drop('hourly', 'astronomy', 'mintempC', 'maxtempC', 'avgtempC')

clean_dyf = DynamicFrame.fromDF(
    clean_df.repartition("location", "year", "month"),
    glue_ctx,
    'cleanweather'
)

glue_ctx.write_dynamic_frame.from_options(
    frame=clean_dyf,
    connection_type="s3",
    connection_options={"path": output_s3_path},
    format="parquet"
)

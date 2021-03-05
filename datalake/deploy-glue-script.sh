#!/bin/bash

set -e

if [ ! -f ../.env ]
then
  echo "Missing environment variable (.env) file."
  echo "Please see .env.example up one directory as example."
  exit 1
fi

source ../.env

set -x

aws s3 cp weather-data-collector/src/glue/etl_raw_weather_data_cleaner.py $WEATHER_DEMO_GLUE_SCRIPT_S3PATH --profile $AWS_PROFILE

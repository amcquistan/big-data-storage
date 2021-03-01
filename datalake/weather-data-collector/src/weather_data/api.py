import json
import logging
import os
from datetime import date, timedelta

import boto3
import requests
import smart_open

logger = logging.getLogger()
logger.setLevel(logging.INFO)

db = boto3.resource('dynamodb')

RESOURCE = 'weather_data'
URL = 'http://api.worldweatheronline.com/premium/v1/past-weather.ashx'


def lambda_handler(event, context):
    tbl = db.Table(os.environ['TABLE_NAME'])

    try:
        response = tbl.get_item(Key={'location': 'lincoln'})
    except Exception as e:
        logger.error({
          'resource': RESOURCE,
          'operation': 'fetch previous request date',
          'error': str(e)
        })
        raise e

    ds = date.fromisoformat(response['Item']['date'])
    ds += timedelta(days=1)
    if ds < date.today():
        params = {
          'q': 'Lincoln,NE',
          'key': os.environ['WEATHER_API_KEY'],
          'format': 'json',
          'date': ds.isoformat(),
          'tp': 1
        }

        try:
            response = requests.get(URL, params=params)
        except Exception as e:
            logger.error({
              'resource': RESOURCE,
              'operation': 'fetch weather data',
              'error': str(e)
            })
            raise e
        
        data = response.json()
        key_opts = {
            'bucket_name': os.environ['BUCKET_NAME'],
            'location': 'lincoln',
            'year': ds.year,
            'month': "{:02d}".format(ds.month),
            'day': "{:02d}".format(ds.day),
            'filename': ds.strftime('%Y%m%d.json') 
        }
        s3_url = "s3://{bucket_name}/rawweatherdata/location={location}/year={year}/month={month}/day={day}/{filename}".format(**key_opts)

        tp = {'session': boto3.Session()}

        try:
            with smart_open.open(s3_url, 'wb', transport_params=tp) as fo:
                fo.write(json.dumps(data['data']['weather'][0]).encode('utf-8'))
        except Exception as e:
            logger.error({
              'resource': RESOURCE,
              'operation': 'save weather data to s3',
              'error': str(e)
            })
            raise e

        try:
            tbl.put_item(Item={'location': 'lincoln', 'date': ds.isoformat()})
        except Exception as e:
            logger.error({
              'resource': RESOURCE,
              'operation': 'save last fetch date to dynamodb',
              'error': str(e)
            })
            raise e

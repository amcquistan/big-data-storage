#!/bin/bash -e

if [ -d aurora-postgres ]; then
  cd ../redshift
fi

if [ -d redshift ]; then
  cd redshift
fi

if [ ! -f ../.env ]; then
  echo "!!! Missing .env file, see env.example for details"
  exit 1
fi

source ../.env


echo ""
echo "-------------------------------------------------------------"
echo "        Creating Pagila S3 Data Export Stored Procs"
echo "-------------------------------------------------------------"

PGPASSWORD=$AURORA_PASSWD psql -e -h $AURORA_HOST \
    -U $AURORA_USER \
    -d $AURORA_NAME \
    -f pagila-oltp-export-to-s3.sql \
    -v s3_bucket="'$ETL_STAGING_BUCKET'" -v aws_region="'$AWS_REGION'"

echo ""
echo "-------------------------------------------------------------"
echo "        Creating Pagila OLAP Star Schema for RedShift"
echo "-------------------------------------------------------------"

PGPASSWORD=$REDSHIFT_PASSWD psql -e -h $REDSHIFT_HOST \
    -p $REDSHIFT_PORT \
    -U $REDSHIFT_USER \
    -d $REDSHIFT_NAME \
    -f pagila-olap-star-schema.sql


echo ""
echo "-------------------------------------------------------------"
echo "                ETL Export to S3 from Aurora"
echo "-------------------------------------------------------------"

PGPASSWORD=$AURORA_PASSWD psql -e -h $AURORA_HOST \
    -U $AURORA_USER \
    -d $AURORA_NAME \
    -c "CALL export_s3_staging_tables();"


echo ""
echo "-------------------------------------------------------------"
echo "               ETL Import from S3 into Redshift"
echo "-------------------------------------------------------------"

PGPASSWORD=$REDSHIFT_PASSWD psql -e -h $REDSHIFT_HOST \
    -p $REDSHIFT_PORT \
    -U $REDSHIFT_USER \
    -d $REDSHIFT_NAME \
    -c "CALL import_s3_staging_tables();"

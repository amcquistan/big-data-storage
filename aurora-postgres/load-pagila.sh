#!/bin/bash -e

if [ -d aurora-postgres ]; then
  cd aurora-postgres
fi

if [ ! -f ../.env ]; then
  echo "!!! Missing .env file, see env.example for details"
  exit 1
fi

source ../.env

echo ""
echo "-------------------------------------------------------------"
echo "                 Creating Pagila OLTP Schema"
echo "-------------------------------------------------------------"

PGPASSWORD=$AURORA_PASSWD psql -h $AURORA_HOST \
    -U $AURORA_USER \
    -d $AURORA_NAME \
    -f pagila-oltp-schema.sql

echo ""
echo "-------------------------------------------------------------"
echo "                 Loading Pagila OLTP Data"
echo "-------------------------------------------------------------"

PGPASSWORD=$AURORA_PASSWD psql -h $AURORA_HOST \
    -U $AURORA_USER \
    -d $AURORA_NAME \
    -f pagila-oltp-data.sql



echo ""
echo "-------------------------------------------------------------"
echo "              Creating Pagila OLAP Star Schema"
echo "-------------------------------------------------------------"

PGPASSWORD=$AURORA_PASSWD psql -e -h $AURORA_HOST \
    -U $AURORA_USER \
    -d $AURORA_NAME \
    -f pagila-olap-star-schema.sql

echo ""
echo "-------------------------------------------------------------"
echo "                Updating DB User Search Path"
echo "-------------------------------------------------------------"

PGPASSWORD=$AURORA_PASSWD psql -e -h $AURORA_HOST \
    -U $AURORA_USER \
    -d $AURORA_NAME \
    -c "ALTER ROLE $AURORA_USER SET search_path TO public, oltp, olap;"

echo ""
echo "-------------------------------------------------------------"
echo "             Performing ELT for OLAP Star Schema"
echo "-------------------------------------------------------------"

PGPASSWORD=$AURORA_PASSWD psql -e -h $AURORA_HOST \
    -U $AURORA_USER \
    -d $AURORA_NAME \
    -c "CALL run_elt();"


#!/bin/bash

# reference: https://aws.amazon.com/blogs/big-data/developing-aws-glue-etl-jobs-locally-using-a-container/

# docker run -itd -p <port_on_host>:<port_on_container_either_8888_or_8080> -p 4040:4040 <credential_setup_to_access_AWS_resources> --name <container_name> amazon/aws-glue-libs:glue_libs_1.0.0_image_01 <command_to_start_notebook_server>

set -e

if [ ! -f ../.env ]
then
  echo "Missing environment variable (.env) file."
  echo "Please see .env.example up one directory as example."
  exit 1
fi

source ../.env

echo "Found creds directory: $AWS_CREDS_DIR"

NOTEBOOKS_DIR=$(pwd)/notebooks

docker run -itd -p 8888:8888 -p 4040:4040 \
    -v $AWS_CREDS_DIR:/root/.aws:ro \
    -v $NOTEBOOKS_DIR:/home/jupyter/jupyter_default_dir \
    --name glue_jupyter amazon/aws-glue-libs:glue_libs_1.0.0_image_01 /home/jupyter/jupyter_start.sh


printf "\n----------------------------------------------------------------------------"
printf "\n%-35s %s" "Glue / Spark Jupyter Notebook:" "http://localhost:8888"
printf "\n%-35s %s" "Spark UI:" "http://localhost:4040"
printf "\n----------------------------------------------------------------------------\n"

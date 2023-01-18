#! /bin/bash

IMAGE_NAME="local_gdr"

# create new image
cp extras/env_local .env
docker build -t $IMAGE_NAME .


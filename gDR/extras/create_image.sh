#! /bin/bash

IMAGE_NAME="local_gdr"

# create new image
cp gDR/extras/env_local .env
docker build --progress=plain -t $IMAGE_NAME .


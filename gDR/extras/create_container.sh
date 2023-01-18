#! /bin/bash

CONTAINER_NAME="gdr_rstudio"

# remove 'rplatform_rstudio' container if already created
cId=$(docker ps -a | grep " ${CONTAINER_NAME}$" | cut -f 1 -d " ")
if [ ! -z "$cId" ]; then docker stop $cId && docker rm $cId; fi

# create new container
docker-compose -f rplatform/docker-compose.yml --project-directory . up -d --force-recreate


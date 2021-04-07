#!/bin/bash

## Use this script to completely destroy and rebuild the docker-compose containers environment from scratch.
## Step 1: import this file to the directly with docker-services.all.yaml file
## Step 2: Make it executable: chmod +x security-services-rebuild.sh
## Step 3: Execute: ./security-services-rebuild.sh


docker container stop $(docker container ls -q)
docker container rm -f $(docker container ls -aq)
docker image rm -f $(docker image ls -q)
docker system prune -f
docker-compose -f docker-services-all.yaml up -d
docker ps

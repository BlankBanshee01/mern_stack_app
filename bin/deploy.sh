#!/bin/bash
if [[ $1 = "prod" || $1 = "dev" ]] && [[ $2 = "up" || $2 = "down" ]]; then
    cd ..
    fileEnv="docker-compose.$1.yaml"
    downOrUp=$2
    echo "Running docker-compose -f $fileEnv $downOrUp"
    docker-compose -f $fileEnv $downOrUp
else
    echo "Need to follow format ./deploy.sh prod|dev down|up"
fi

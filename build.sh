#!/bin/bash
IMAGE_SRC=jenkins/jnlp-slave
TAG=papanito/jnlp-slave
VERSION=latest-jdk11
sudo docker login $REPO
sudo docker build .  --no-cache --tag $REPO/$TAG:$VERSION --build-arg APP_IMAGE=$IMAGE_SRC:$VERSION
sudo docker push $REPO/$TAG
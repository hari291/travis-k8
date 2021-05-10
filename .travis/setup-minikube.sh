#!/bin/bash

minikube-version="v1.18.1"
 
JOB_NAME_SUFFIX="alpine next"
 
#https://github.com/che-incubator/setup-minikube-action/blob/main/src/minikube-setup-helper.ts
MINIKUBE_OWN_PATH="/usr/local/sbin/minikube"
MINIKUBE_VERSION="v1.18.1"
MINIKUBE_VERSION_DEFAULT="v1.18.1"

if [[ -n "${MINIKUBE_VERSION}" ]]; then
  echo "Minikube version not specified. Will use pre-installed minikube version"
  MINIKUBE_VERSION="${MINIKUBE_VERSION_DEFAULT}"
fi

MINIKUBE_LINK="https://github.com/kubernetes/minikube/releases/download/${MINIKUBE_VERSION}/minikube-linux-amd64"
echo "Downloading minikube $MINIKUBE_VERSION..."
sudo curl $MINIKUBE_LINK -Lo $MINIKUBE_OWN_PATH

echo "Make minikube executable"
sudo -E chmod 755 $MINIKUBE_OWN_PATH

echo "Minikube installed at $MINIKUBE_OWN_PATH"

#https://github.com/che-incubator/setup-minikube-action/blob/main/src/minikube-start-helper.ts
CHANGE_MINIKUBE_NONE_USER="true"
MINIKUBE_WANTUPDATENOTIFICATION="false"
 
echo "Starting minikube..."
minikube start --vm-driver=docker --addons=ingress --cpus 2 --memory 6500

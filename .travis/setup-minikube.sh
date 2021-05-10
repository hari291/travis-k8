#!/bin/bash

JOB_NAME_SUFFIX="alpine next"

# install kubectl
KUBECTL_VERSION="v1.17.17"
KUBECTL_OWN_PATH="/usr/local/bin/kubectl"
KUBECTL_LINK="https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/$TRAVIS_CPU_ARCH/kubectl"
sudo curl $KUBECTL_LINK -Lo $KUBECTL_OWN_PATH
sudo chmod +x $KUBECTL_OWN_PATH
echo "kubectl version"
kubectl version --client
 
#https://github.com/che-incubator/setup-minikube-action/blob/main/src/minikube-setup-helper.ts
MINIKUBE_OWN_PATH="/usr/local/sbin/minikube"
MINIKUBE_VERSION="v1.18.1"
MINIKUBE_VERSION_DEFAULT="v1.18.1"

if [[ -n "${MINIKUBE_VERSION}" ]]; then
  echo "Minikube version not specified. Will use pre-installed minikube version"
  MINIKUBE_VERSION="${MINIKUBE_VERSION_DEFAULT}"
fi

MINIKUBE_LINK="https://github.com/kubernetes/minikube/releases/download/${MINIKUBE_VERSION}/minikube-linux-$TRAVIS_CPU_ARCH"
echo "Downloading minikube $MINIKUBE_VERSION..."
sudo curl $MINIKUBE_LINK -Lo $MINIKUBE_OWN_PATH

echo "Make minikube executable"
sudo -E chmod 755 $MINIKUBE_OWN_PATH

echo "Minikube installed at $MINIKUBE_OWN_PATH"

#https://github.com/che-incubator/setup-minikube-action/blob/main/src/minikube-start-helper.ts
CHANGE_MINIKUBE_NONE_USER="true"
MINIKUBE_WANTUPDATENOTIFICATION="false"
 
#MEMORY=6500
echo "Starting minikube..."
minikube start --vm-driver=docker --addons=ingress --cpus 2 --memory 2000

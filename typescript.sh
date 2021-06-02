#!/bin/bash

set -x

KUBECTL_VERSION="v1.20.2"
KUBECTL_OWN_PATH="/usr/local/bin/kubectl"
KUBECTL_LINK="https://storage.googleapis.com/kubernetes-release/release/${KUBECTL_VERSION}/bin/linux/$TRAVIS_CPU_ARCH/kubectl"
sudo curl $KUBECTL_LINK -Lo $KUBECTL_OWN_PATH
sudo chmod +x $KUBECTL_OWN_PATH
echo "kubectl version"
kubectl version --client

npm install -g typescript
export RUNNER_TEMP=/tmp
export SKIP_TEST=true
export SKIP_FORMAT=true
#export NODE_ENV=production
export GITHUB_ENV=/tmp/github_env
touch $GITHUB_ENV

function ExtractVariable()
{
	local VAR=$1
	BEGIN=$VAR'<<_GitHubActionsFileCommandDelimeter_'
	END='_GitHubActionsFileCommandDelimeter_'
	echo `sed -n '/'"$BEGIN"'/,/'"$END"'/{/'"$BEGIN"'/!{/'"$END"'/!p}}' $GITHUB_ENV`
}

git clone https://github.com/Siddhesh-Ghadi/setup-minikube-action.git
cd setup-minikube-action
npm install
#env 'INPUT_MINIKUBE-VERSION=v1.18.1' node lib/index.js
export MINIKUBE_VERSION=v1.18.1
eval node lib/index.js
#node lib/index.js
env
cd ..


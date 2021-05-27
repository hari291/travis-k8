#!/bin/bash

set -x

git clone https://github.com/eclipse-che/che-theia.git
cd che-theia
docker pull quay.io/eclipse/che-theia-dev:next
docker tag quay.io/eclipse/che-theia-dev:next eclipse/che-theia-dev:next
./build.sh --root-yarn-opts:--ignore-scripts --dockerfile:Dockerfile.alpine


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
export SKIP_LINT=true
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

#git clone https://github.com/che-incubator/setup-minikube-action.git
#cd setup-minikube-action
#npm install
#env 'INPUT_MINIKUBE-VERSION=v1.18.1' node lib/index.js
#cd ..
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
 
#MEMORY=6500
echo "Starting minikube..."
minikube start --vm-driver=docker --addons=ingress --cpus 2 --memory 6500

git clone https://github.com/Siddhesh-Ghadi/che-deploy-action.git
cd che-deploy-action
npm install
env 'INPUT_CHECTL-CHANNEL=next' node lib/index.js
cd ..

echo "devfile-che-theia"
cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: custom-devfile-deployment
  labels:
    app: customdevfile
spec:
  selector:
    matchLabels:
      app: customdevfile
  template:
    metadata:
      labels:
        app: customdevfile
    spec:
      containers:
      - name: customdevfile
        image: docker.io/httpd:2.4.46-alpine
        ports:
        - containerPort: 80
EOF
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: customdevfile-service
spec:
  type: ClusterIP
  selector:
    app: customdevfile
  ports:
    - port: 80
      targetPort: 80
EOF
cat <<EOF | kubectl apply -f -
apiVersion: extensions/v1beta1
kind: Ingress
metadata:
  annotations:
    kubernetes.io/ingress.class: nginx
  name: custom-devfile
spec:
  rules:
  - host: custom-devfile.$(minikube ip).nip.io
    http:
      paths:
      - backend:
          serviceName: customdevfile-service
          servicePort: 80
        path: /
        pathType: ImplementationSpecific
EOF
while [[ $(kubectl get pods -l app=customdevfile -o 'jsonpath={..status.conditions[?(@.type=="Ready")].status}') != "True" ]]; do echo "waiting for pod" && sleep 1; done
while [[ $(kubectl get ingress/custom-devfile -o 'jsonpath={..status.loadBalancer.ingress[0].ip}') != "$(minikube ip)" ]]; do echo "waiting for ingress" && sleep 1; done
DEPLOY_POD_NAME=$(kubectl get pods -l app=customdevfile  -o 'jsonpath={...metadata.name}')

export DEVFILE_CUSTOM_URL=http://custom-devfile.$(minikube ip).nip.io/devfile.yaml
export CHE_THEIA_META_YAML_URL='https://che-plugin-registry-main.surge.sh/v3/plugins/eclipse/che-theia/next/meta.yaml'
wget $CHE_THEIA_META_YAML_URL -O che-theia-meta.yaml
sed -i 's|quay.io/eclipse/che-theia:next|local-che-theia:latest|' che-theia-meta.yaml
sed -i 's|quay.io/eclipse/che-theia-endpoint-runtime-binary:next|local-che-theia-endpoint-runtime-binary:latest|' che-theia-meta.yaml
# patch happy-path-workspace.yaml
wget https://raw.githubusercontent.com/eclipse/che/master/tests/e2e/files/happy-path/happy-path-workspace.yaml -O devfile.yaml
sed -i "s|id: eclipse/che-theia/next|alias: che-theia\n    reference: http://custom-devfile.$(minikube ip).nip.io/che-theia-meta.yaml|" devfile.yaml
kubectl cp che-theia-meta.yaml $DEPLOY_POD_NAME:/usr/local/apache2/htdocs/
kubectl cp devfile.yaml $DEPLOY_POD_NAME:/usr/local/apache2/htdocs/
echo "::set-output name=devfile-url::http://custom-devfile.$(minikube ip).nip.io/devfile.yaml"
export DEVFILE_URL="http://custom-devfile.$(minikube ip).nip.io/devfile.yaml"
echo "devfile yaml content from http://custom-devfile.$(minikube ip).nip.io/devfile.yaml is:"
curl http://custom-devfile.$(minikube ip).nip.io/devfile.yaml
echo "che-theia-meta.yaml content from http://custom-devfile.$(minikube ip).nip.io/che-theia-meta.yaml is:"
curl http://custom-devfile.$(minikube ip).nip.io/che-theia-meta.yaml

docker tag eclipse/che-theia:next local-che-theia:latest
docker tag eclipse/che-theia-endpoint-runtime-binary:next local-che-theia-endpoint-runtime-binary:latest
docker save -o che-theia-images.tar local-che-theia:latest local-che-theia-endpoint-runtime-binary:latest
docker image prune -a -f
eval $(minikube docker-env)
docker load --input=che-theia-images.tar
rm che-theia-images.tar

export CHE_URL=$(ExtractVariable CHE_URL)  
#git clone https://github.com/che-incubator/happy-path-tests-action.git
#cd happy-path-tests-action
#npm install
#export CHE_URL=$(ExtractVariable CHE_URL)  
#env 'INPUT_CHE-URL='$CHE_URL 'INPUT_DEVFILE-URL='$DEVFILE_URL 'INPUT_E2E-VERSION=next' node lib/index.js
#cd ..

#-----------------------------
# happy-path-tests-action
# functions called: https://github.com/che-incubator/happy-path-tests-action/blob/main/src/launch-happy-path.ts#L33
#
#-----------------------------
#Eclipse Che [clone]...
echo 'Cloning eclipse che for happy path tests'
git clone --depth 1 https://github.com/eclipse/che

#Images [pull]...
echo 'Setup docker-env of minikube'
minikube docker-env
source <(minikube docker-env)
devfileUrl=$DEVFILE_URL
#TODO: reading content from file
#https://github.com/che-incubator/happy-path-tests-action/blob/main/src/images-helper.ts#L51
IMAGES="/tmp/images"
touch $IMAGES
devfileContent=$(curl -s $devfileUrl)
echo "${devfileContent}"|sed -n 's/image: [>-]*\n*\(.*\)/\1/p'|tee -a $IMAGES

mId=$(echo "${devfileContent}"|sed -n 's/id: \(.*\)/\1/p')
echo "${mId}" | while read componentId; do
    if [[ ! -z $componentId ]]
    then
      pluginIdContent=$(curl -s https://che-plugin-registry-main.surge.sh/v3/plugins/${componentId}/meta.yaml)
      tmp=$(echo "${pluginIdContent}"|sed -n 's/image: [>-]*\n*\(.*\)/\1/p')
      echo "$tmp" >> $IMAGES
    fi    
done

mReference=$(echo "${devfileContent}"|sed -n 's/reference: \(.*\)/\1/p')
echo "${mReference}" | while read reference; do
    if [[ ! -z $reference ]]
    then
      content=$(curl -s $reference)
      tmp=$(echo "${content}"|sed -n 's/image: [>-]*\n*\(.*\)/\1/p')
      echo "$tmp" >> $IMAGES
    fi    
done

#skip images that are prefixed with 'local-'
sed -i '/local-/d' $IMAGES
#remove extra space, - & '
sed -i "s/^[ \t]*//" $IMAGES
sed -i 's/^-//g' $IMAGES
sed -i "s/'//g" $IMAGES

cat $IMAGES | xargs -n1 docker pull

#Workspace [start]...
#https://github.com/che-incubator/happy-path-tests-action/blob/main/src/workspace-helper.ts#L42
echo 'Create and start workspace...'
devfileUrl=$DEVFILE_URL
echo "DevFile Path selected to ${devfileUrl}"
workspaceStartEndProcess="$(chectl workspace:create --start --devfile=${devfileUrl})"
workspaceUrlExec="$(echo "${workspaceStartEndProcess}"|sed -n 's/.*\(https:\/\/.*\).*/\1/p' )"
if [ -z "$workspaceUrlExec" ]
then
  echo "Unable to find workspace URL in stdout of workspace:create process. Found ${workspaceStartEndProcess}"
  exit 1
fi
$WORKSPACE_URL="${workspaceUrlExec}"
echo "Detect as workspace URL the value ${workspaceUrl}"
while [[ $(kubectl get pods -n admin-che -l app=che.workspace_id -o 'jsonpath={..status.conditions[?(@.type=="Running")].status}') != "True" ]]; do echo "waiting for workspace" && sleep 1; done
# todo: https://github.com/che-incubator/happy-path-tests-action/blob/main/src/workspace-helper.ts#L53

#Happy Path [start]...
#https://github.com/che-incubator/happy-path-tests-action/blob/main/src/happy-path-helper.ts#L23
cheUrl=${CHE_URL}
echo "Happy path tests will use Eclipse Che URL: ${cheUrl}"
e2eFolder="${PWD}/che/tests/e2e"
params="--shm-size=1g --net=host --ipc=host -p 5920:5920 -e VIDEO_RECORDING=false -e TS_SELENIUM_HEADLESS=false -e TS_SELENIUM_DEFAULT_TIMEOUT=300000 -e TS_SELENIUM_LOAD_PAGE_TIMEOUT=240000 -e TS_SELENIUM_WORKSPACE_STATUS_POLLING=20000 -e TS_SELENIUM_PREVIEW_WIDGET_DEFAULT_TIMEOUT=20000 -e TS_SELENIUM_BASE_URL=${cheUrl}-e TS_SELENIUM_LOG_LEVEL=TRACE -e TS_SELENIUM_MULTIUSER=true -e TS_SELENIUM_USERNAME=admin -e TS_SELENIUM_PASSWORD=admin -e NODE_TLS_REJECT_UNAUTHORIZED=0 -v ${e2eFolder}:/tmp/e2e quay.io/eclipse/che-e2e:${E2E_VERSION}"
echo "Launch docker command ${params}"
unset DOCKER_HOST
unset DOCKER_TLS_VERIFY
env>env_file
docker run --env-file=env_file ${params}

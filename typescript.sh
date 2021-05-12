#!/bin/bash

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

git clone https://github.com/che-incubator/setup-minikube-action.git
cd setup-minikube-action
npm install
env 'INPUT_MINIKUBE-VERSION=v1.18.1' node lib/index.js
cd ..

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

git clone https://github.com/che-incubator/happy-path-tests-action.git
cd happy-path-tests-action
npm install
export CHE_URL=$(ExtractVariable CHE_URL)  
env 'INPUT_CHE-URL='$CHE_URL 'INPUT_DEVFILE-URL='$DEVFILE_URL 'INPUT_E2E-VERSION=next' node lib/index.js
cd ..

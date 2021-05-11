#!/bin/bash

set -e

#https://github.com/che-incubator/che-deploy-action/blob/main/src/chectl-helper.ts
echo "Chectl [download]..."
CHECTL_SCRIPT_PATH="/tmp/chectl-install.sh"
echo "Downloading chectl installer..."
curl -sLo $CHECTL_SCRIPT_PATH https://www.eclipse.org/che/chectl/
echo "Making it executable..."
chmod 755 $CHECTL_SCRIPT_PATH

echo "Chectl [configure]..."
echo "configuring chectl defaults..."
if [[ -n "${HOME}" ]]; then
  echo "No HOME environment variable found"
  exit 1
fi
local chectlConfigFolderPath="$HOME/.config/chectl"
mkdir -p $chectlConfigFolderPath
local chectlConfigPath="$chectlConfigFolderPath/config.json"
// disable telemetry
echo "{ 'segment.telemetry': 'off' }" > $chectlConfigPath

echo "Chectl [install]..."
local channel="${CHANNEL:next}"
if [[ $channel !== 'next' && $channel !== 'stable' ]]; then
  echo "Invalid channel set for chectl: should be stable or next"
  exit 1
fi
echo "Installing chectl [channel=${channel}]...";
$CHECTL_SCRIPT_PATH --channel=${channel}

#https://github.com/che-incubator/che-deploy-action/blob/main/src/che-helper.ts
echo "Eclipse Che [serverDeploy]..."
echo "Calling chectl server:deploy..."
DEFAULT_CONFIG='{
  "spec":{
    "auth":{
      "updateAdminPassword":false
    },
    "server":{
      "customCheProperties":{
        "CHE_WORKSPACE_SIDECAR_IMAGE__PULL__POLICY":"IfNotPresent",
        "CHE_WORKSPACE_PLUGIN__BROKER_PULL__POLICY":"IfNotPresent",
        "CHE_INFRA_KUBERNETES_PVC_JOBS_IMAGE_PULL__POLICY":"IfNotPresent"
      }
    }
  }
}' 

#TODO: https://github.com/che-incubator/che-deploy-action/blob/main/src/che-helper.ts#L43-L70
local customResourceContent=
CUSTOM_RESOURCE_PATH="/tmp/custom-resource-patch.yaml"

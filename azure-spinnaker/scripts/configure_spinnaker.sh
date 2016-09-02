#!/bin/bash

APP_NAME=$1
REGION=$2

if [[ -z "$APP_NAME" ]]; then
    APP_NAME="mytestapp"
fi

if [[ -z "$REGION" ]]; then
    REGION="eastus"
fi

echo " "
echo "Default Application Name: $APP_NAME"
echo "Default region: $REGION"
echo " "

echo "Launching Spinnaker....."
sudo bash -c '/opt/spinnaker/scripts/start_spinnaker.sh'

echo " "
echo "Waiting for all process to be ready...."
sleep 30
echo " "

STACK="st1"
APPG_DETAIL="frontend"
APP_GATEWAY_NAME="$APP_NAME-$STACK-$APPG_DETAIL"
PIPELINE_NAME=$APP_NAME"pipeline"
PIPELINE_DETAIL="demo"

echo "Demo Application Name: " $APP_NAME 
echo "Demo Load Balancer: " $APP_GATEWAY_NAME
echo "Demo Pipeline: " $PIPELINE_NAME

# Create an application in Spinnaker
echo "Creating default application \"$APP_NAME\" in Spinnaker"
APP_RESPONSE=sudo curl -X POST --header "Content-Type: application/json" --header "Accept: */*" -d "{\"job\": [ { \"type\": \"createApplication\", \"account\": \"my-azure-account\", \"application\": { \"cloudProviders\": \"azure\", \"instancePort\": \"null\", \"name\": \"$APP_NAME\", \"email\":\"spinnakeruser@outlook.com\" }, \"user\": \"[anonymous]\" }], \"application\": \"$APP_NAME\", \"description\": \"Create Application: $APP_NAME\"}" "http://localhost:8084/applications/$APP_NAME/tasks"
echo "Demo Application $APP_NAME created"

# Create a load balancer (Azure App Gateway)
echo "Creating default application gateway \"$APP_GATEWAY_NAME\" in Spinnaker"
APPGATE_RESPONSE=sudo curl -X POST --header "Content-Type: application/json" --header "Accept: */*" -d "[ {\"upsertLoadBalancer\": {\"cloudProvider\": \"azure\",\"appName\": \"$APP_NAME\",\"loadBalancerName\": \"$APP_GATEWAY_NAME\",\"stack\": \"$STACK\",\"detail\": \"$APPG_DETAIL\",\"credentials\": \"my-azure-account\",\"region\": \"$REGION\",\"probes\": [{\"probeName\": \"healthcheck1\",\"probeProtocol\": \"HTTP\",\"probePort\": \"localhost\",\"probePath\": \"/\",\"probeInterval\": 30,\"unhealthyThreshold\": 8,\"timeout\": 120}],\"loadBalancingRules\": [{\"ruleName\": \"$APP_GATEWAY_NAME-rule0\",\"protocol\": \"HTTP\",\"externalPort\": 80,\"backendPort\": 80,\"probeName\": \"$APP_GATEWAY_NAME-probe\",\"persistence\": \"None\", \"idleTimeout\": 4 }], \"name\":\"$APP_GATEWAY_NAME\",\"user\": \"[anonymous]\"}}]" "http://localhost:7002/azure/ops"
echo "Demo Load Balancer $APP_GATEWAY_NAME created"

# Create a pipeline with bake and deploy stage
CREATE_PIPELINE_DATA="{\"application\":\"$APP_NAME\",\"appConfig\":{},\"keepWaitingPipelines\":false,\"limitConcurrent\":true,\"parallel\":true,\"name\":\"$PIPELINE_NAME\",\"stages\":[{\"baseLabel\":\"release\",\"baseName\":\"test\",\"baseOs\":\"ubuntu\",\"cloudProviderType\":\"azure\",\"extendedAttributes\":{},\"name\":\"Bake\",\"osType\":\"Linux\",\"package\":\"gedit\",\"refId\":\"1\",\"regions\":[\"$REGION\"],\"requisiteStageRefIds\":[],\"type\":\"bake\",\"user\":\"[anonymous]\"},{\"clusters\":[{\"account\":\"my-azure-account\",\"application\":\"$APP_NAME\",\"capacity\":{\"max\":1,\"min\":1,\"useSourceCapacity\":false},\"cloudProvider\":\"azure\",\"detail\":\"$PIPELINE_DETAIL\",\"freeFormDetails\":\"$PIPELINE_DETAIL\",\"image\":{\"imageName\":\"\",\"isCustom\":\"true\",\"offer\":\"\",\"ostype\":\"\",\"publisher\":\"\",\"region\":\"$REGION\",\"sku\":\"\",\"uri\":\"\",\"version\":\"\"},\"interestingHealthProviderNames\":[],\"loadBalancerName\":\"$APP_GATEWAY_NAME\",\"name\":\"$APP_NAME-$STACK-$PIPELINE_DETAIL\",\"osConfig\":{\"adminPassword\":\"!Qnti**234\",\"adminUserName\":\"spinnakeruser\"},\"region\":\"$REGION\",\"selectedProvider\":\"azure\",\"sku\":{\"capacity\":1,\"name\":\"Standard_DS1_v2\",\"tier\":\"Standard\"},\"stack\":\"$STACK\",\"type\":\"createServerGroup\",\"upgradePolicy\":\"Manual\",\"user\":\"[anonymous]\",\"viewState\":{\"allImageSelection\":null,\"disableImageSelection\":true,\"disableStrategySelection\":false,\"hideClusterNamePreview\":false,\"imageId\":null,\"instanceProfile\":\"custom\",\"loadBalancersConfigured\":true,\"mode\":\"createPipeline\",\"readOnlyFields\":{},\"securityGroupsConfigured\":true,\"submitButtonLabel\":\"Add\",\"templatingEnabled\":true,\"useAllImageSelection\":false,\"usePreferredZones\":true,\"useSimpleCapacity\":true}}],\"name\":\"Deploy\",\"refId\":\"2\",\"requisiteStageRefIds\":[\"1\"],\"type\":\"deploy\"}],\"triggers\":[]}"
sudo curl -X POST --header "Content-Type: application/json" --header "*/*" -d "$CREATE_PIPELINE_DATA" "http://localhost:8084/pipelines"
echo "Demo pipelname $PIPELINE_NAME created"

echo "Spinnaker demo setup complete"
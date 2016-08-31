##!/bin/bash

echo "In order to use Spinnaker with Azure you first create a service principal for Spinnaker to run as and also to manage your azure subscription."
echo "Background article: https://azure.microsoft.com/en-us/documentation/articles/resource-group-authenticate-service-principal/#authenticate-with-password---azure-cli"
echo "Execute the following commands:"
echo "    azure login"
echo "    azure config mode arm"
echo "    azure account show"
echo "From above record the 'data: ID' and 'data: Tenant ID' - these will be your subscription ID and tenant ID"
echo " "
echo "Create your application in Azure AD"
echo "    azure ad app create --name 'exampleapp' --home-page 'https://www.contoso.org' --identifier-uris 'https://www.contoso.org/example' --password <Your_Password>"
echo "From above record the 'data: AppId' - this will be your client ID while the password that was set will be the AppKey"
echo " "
echo "Create service principal"
echo "    azure ad sp create <AppId from previous step>"
echo " "
echo "Assign rights to service principal"
echo "    azure role assignment create --objectId <Object ID from above step> -o Owner -c /subscriptions/{subscriptionId from above step}/"

my_spinnaker_config_path="/opt/spinnaker/config"
my_azure_spinnaker_config_path="$my_spinnaker_config_path/azure_config"

my_app_name="spinnakertrialapp"
my_app_key="mysp1nn8k3rtr1al0ff3r"
my_app_id_URI=$my_app_name"_id"

# request the user to login. Azure CLI requires an interactive log in. If the user is already logged in, the asking them to login
# again is effectively a no-op, although since this script is most likely to be run the first time they logon to the VM, they should not 
# already be logged in.
echo "******* PLEASE LOGIN *******"
azure login

sub_count=$(azure account list --json | jq '. | length')

if [[ $sub_count -gt 1 ]]; then
  echo " "
  echo "***************************************************************************"
  echo "Please enter the name of correct subscription to use from the list below."
  echo "Press enter to use the \"current\" subscription"
  echo "***************************************************************************"
  azure account list
  echo " "
  echo "Subscription name:"
  read sub_to_use
  if [[ -n "$sub_to_use" ]]; then
    echo "Switching to $sub_to_use..."
    azure account set "$sub_to_use"
    if [[ $? -gt 0 ]]; then
      echo "Error encountered trying to switch to desired subscription. Please verify the name and restart this script"
      exit 1
    fi 
  fi
fi

my_subscription_id=$(azure account show --json | jq -r '.[0].id')
my_tenant_id=$(azure account show --json | jq -r '.[0].tenantId')

azure config mode arm

my_error_check=$(azure ad sp show --search $my_app_name --json | grep "displayName" | grep -c \"$my_app_name\" )

if [ $my_error_check -gt 0 ];
then
  echo " "
  echo "Found an app id matching the one we are trying to create; we will reuse that instead"
else
  echo " "
  echo "Creating application in active directory:"
  echo "azure ad app create --name '$my_app_name' --home-page 'http://$my_app_name' --identifier-uris 'http://$my_app_id_URI/' --password $my_app_key"
  azure ad app create --name $my_app_name --home-page http://$my_app_name --identifier-uris http://$my_app_id_URI/ --password $my_app_key
  # Give time for operation to complete
  echo "Waiting for operation to complete...."
  sleep 20
  my_error_check=$(azure ad app show --search $my_app_name --json | grep "displayName" | grep -c \"$my_app_name\" )
 
  if [ $my_error_check -gt 0 ];
  then
    my_app_object_id=$(azure ad app show --json --search $my_app_name | jq -r '.[0].objectId')
    my_client_id=$(azure ad app show --json --search $my_app_name | jq -r '.[0].appId')
    echo " "
    echo "Creating the service principal in AD"
    echo "azure ad sp create -a $my_client_id"
    azure ad sp create -a $my_client_id
    # Give time for operation to complete
    echo "Waiting for operation to complete...."
    sleep 20
    my_app_sp_object_id=$(azure ad sp show --search $my_app_name --json | jq -r '.[0].objectId')
    
    echo "Assign rights to service principle"
    echo "azure role assignment create --objectId $my_app_sp_object_id -o Owner -c /subscriptions/$my_subscription_id"
    azure role assignment create --objectId $my_app_sp_object_id -o Owner -c /subscriptions/$my_subscription_id
  else
    echo " "
    echo "We've encounter an unexpected error; please hit Ctr-C and retry from the beginning"
    read my_error
  fi
fi

my_client_id=$(azure ad sp show --search $my_app_name --json | jq -r '.[0].appId')

echo " "
echo "Subscription ID:" $my_subscription_id
echo "Tenant ID:" $my_tenant_id
echo "Client ID:" $my_client_id
echo "App Key:" $my_app_key
echo " "
echo "You can verify the service principal was created properly by running:"
echo "azure login -u "$my_client_id" --service-principal --tenant $my_tenant_id"
echo " "

my_default_resource_group="SpinnakerDefault"
my_packer_resource_group="SpinnakerDefault"
default_location="eastus"
my_key_vault_name="NYI"
my_key_vault_resource_group=$my_default_resource_group

# Create the resource group. If it already exists, this call will "update" the Group which in our case will be a no-op
azure group create $my_default_resource_group $default_location

my_packer_storage_account=''
if [ -z $my_packer_storage_account ];
then
  # the storage account must be unique; use a random number generator to set the postfix for the storage account
  my_rand_postfix=$(od -vAn -N4 -tu4 < /dev/urandom)
  my_rand_postfix=$(echo -e "$my_rand_postfix" | sed -e 's/^[[:space:]]*//')
  echo "Set default packer resource group to packer$my_rand_postfix"
  my_packer_storage_account="packer$my_rand_postfix"
  # TODO -create the storage account in Azure
fi

# Create the packer storage account
PACKER_STORAGE_DEPLOYMENT="$my_packer_storage_account-deployment"
PACKER_SA_TEMPLATE_FILE="packerstorageacct.json"
PACKER_SA_TEMPLATE_TARGET="$my_azure_spinnaker_config_path/$PACKER_SA_TEMPLATE_FILE"
PACKER_SA_TEMPLATE_SOURCE="https://raw.githubusercontent.com/scotmoor/azure-quickstart-templates/master/azure-spinnaker/scripts/$PACKER_SA_TEMPLATE_FILE"
sudo curl -o $PACKER_SA_TEMPLATE_TARGET $PACKER_SA_TEMPLATE_SOURCE
azure group deployment create -g $my_default_resource_group -n "$PACKER_STORAGE_DEPLOYMENT" -f "$PACKER_SA_TEMPLATE_TARGET" -p "{\"storage_account_name\": {\"value\":\"$my_packer_storage_account\"}, \"location\":{\"value\": \"$default_location\"}}"

echo " "
echo "Default Resource Group:" $my_default_resource_group

echo "Packer Resource Group:" $my_default_resource_group
echo "Packer Storage Account:" $my_packer_storage_account
echo " "
echo "Press enter to continue"
read my_enter

# Update Spinnaker configuration file with the credentials set above
echo " "
echo "Update Spinnaker configuration file using the credentials set above"
echo " "

echo "cp $my_azure_spinnaker_config_path/azure_config/spinnaker-local.yml $HOME/spinnaker-local.yml"
cp $my_azure_spinnaker_config_path/spinnaker-local.yml $HOME/spinnaker-local.yml
echo "sed -i s/MY_AZURE_SUBSCRIPTION_ID/$my_subscription_id/g $HOME/spinnaker-local.yml"
sed -i s/MY_AZURE_SUBSCRIPTION_ID/$my_subscription_id/g $HOME/spinnaker-local.yml
echo "sed -i s/MY_AZURE_TENANT_ID/$my_tenant_id/g $HOME/spinnaker-local.yml"
sed -i s/MY_AZURE_TENANT_ID/$my_tenant_id/g $HOME/spinnaker-local.yml
echo "sed -i s/MY_AZURE_CLIENT_ID/$my_client_id/g $HOME/spinnaker-local.yml"
sed -i s/MY_AZURE_CLIENT_ID/$my_client_id/g $HOME/spinnaker-local.yml
echo "sed -i s/MY_AZURE_APP_KEY/$my_app_key/g $HOME/spinnaker-local.yml"
sed -i s/MY_AZURE_APP_KEY/$my_app_key/g $HOME/spinnaker-local.yml
# TODO: Enable Key vault support 
echo "sed -i s/MY_AZURE_RESOURCE_GROUP/$my_key_vault_resource_group/g $HOME/spinnaker-local.yml"
sed -i s/MY_AZURE_RESOURCE_GROUP/$my_key_vault_resource_group/g $HOME/spinnaker-local.yml
echo "sed -i s/MY_AZURE_KEY_VAULT/$my_key_vault_name/g $HOME/spinnaker-local.yml"
sed -i s/MY_AZURE_KEY_VAULT/$my_key_vault_name/g $HOME/spinnaker-local.yml
echo "sed -i s/MY_AZURE_PACKER_RESOURCE_GROUP/$my_packer_resource_group/g $HOME/spinnaker-local.yml"
sed -i s/MY_AZURE_PACKER_RESOURCE_GROUP/$my_packer_resource_group/g $HOME/spinnaker-local.yml
echo "sed -i s/MY_AZURE_PACKER_STORAGE_ACCOUNT/$my_packer_storage_account/g $HOME/spinnaker-local.yml"
sed -i s/MY_AZURE_PACKER_STORAGE_ACCOUNT/$my_packer_storage_account/g $HOME/spinnaker-local.yml

echo "sudo bash -c 'cp $HOME/spinnaker-local.yml /opt/spinnaker/config/spinnaker-local.yml'"
sudo bash -c 'cp $HOME/spinnaker-local.yml /opt/spinnaker/config/spinnaker-local.yml'
echo "sudo bash -c 'cp /opt/spinnaker/config/azure_config/clouddriver.yml /opt/spinnaker/config/clouddriver.yml'"
sudo bash -c 'cp /opt/spinnaker/config/azure_config/clouddriver.yml /opt/spinnaker/config/clouddriver.yml'
echo "sudo bash -c 'cp /opt/spinnaker/config/azure_config/rosco.yml /opt/spinnaker/config/rosco.yml'"
sudo bash -c 'cp /opt/spinnaker/config/azure_config/rosco.yml /opt/spinnaker/config/rosco.yml'

echo "Start Spinnaker"
sudo bash -c '/opt/spinnaker/scripts/start_spinnaker.sh'
sleep 30

APP_NAME="mydemoapp"
STACK="st1"
APPG_DETAIL="frontend"
APP_GATEWAY_NAME="$APP_ANME-$STACK-$APPG_DETAIL"
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
echo "Creating default application gateway \"$APP_NAME-$STACK-$APPG_DETAIL\" in Spinnaker"
APPGATE_RESPONSE=sudo curl -X POST --header "Content-Type: application/json" --header "Accept: */*" -d "[ {\"upsertLoadBalancer\": {\"cloudProvider\": \"azure\",\"appName\": \"$APP_NAME\",\"loadBalancerName\": \"$APP_NAME-$STACK-$APPG_DETAIL\",\"stack\": \"$STACK\",\"detail\": \"$APPG_DETAIL\",\"credentials\": \"my-azure-account\",\"region\": \"$default_location\",\"probes\": [{\"probeName\": \"healthcheck1\",\"probeProtocol\": \"HTTP\",\"probePort\": \"localhost\",\"probePath\": \"/\",\"probeInterval\": 30,\"unhealthyThreshold\": 8,\"timeout\": 120}],\"loadBalancingRules\": [{\"ruleName\": \"$APP_NAME-$STACK-$APPG_DETAIL-rule0\",\"protocol\": \"HTTP\",\"externalPort\": 80,\"backendPort\": 80,\"probeName\": \"$APP_NAME-$STACK-$APPG_DETAIL-probe\",\"persistence\": \"None\", \"idleTimeout\": 4 }], \"name\":\"$APP_NAME-$STACK-$APPG_DETAIL\",\"user\": \"[anonymous]\"}}]" "http://localhost:7002/azure/ops"
echo "Demo Load Balancer $APP_GATEWAY_NAME created"


# Create a pipeline with bake and deploy stage
CREATE_PIPELINE_DATA="{\"application\":\"$APP_NAME\",\"index\":2,\"keepWaitingPipelines\":false,\"limitConcurrent\":true,\"name\":\"$PIPELINE_NAME\",\"stages\":[{\"baseLabel\":\"release\",\"baseOs\":\"ubuntu\",\"cloudProviderType\":\"azure\",\"extendedAttributes\":{},\"name\":\"Bake\",\"osType\":\"Linux\",\"package\":\"jenkins\",\"regions\":[\"eastus\",\"westus\"],\"type\":\"bake\",\"user\":\"[anonymous]\"},{\"clusters\":[{\"account\":\"my-azure-account\",\"application\":\"$APP_NAME\",\"capacity\":{\"max\":1,\"min\":1,\"useSourceCapacity\":false},\"cloudProvider\":\"azure\",\"detail\":\"$PIPELINE_DETAIL\",\"freeFormDetails\":\"$PIPELINE_DETAIL\",\"image\":{\"imageName\":\"\",\"isCustom\":\"true\",\"offer\":\"\",\"ostype\":\"\",\"publisher\":\"\",\"region\":\"$default_location\",\"sku\":\"\",\"uri\":\"\",\"version\":\"\"},\"interestingHealthProviderNames\":[],\"loadBalancerName\":\"$APP_GATEWAY_NAME\",\"name\":\"$APP_NAME-$STACK-$PIPELINE_DETAIL\",\"osConfig\":{\"adminPassword\":\"!Qnti**234\",\"adminUserName\":\"spinnakeruser\"},\"region\":\"$default_location\",\"selectedProvider\":\"azure\",\"sku\":{\"capacity\":1,\"name\":\"Standard_DS1_v2\",\"tier\":\"Standard\"},\"stack\":\"$STACK\",\"type\":\"createServerGroup\",\"upgradePolicy\":\"Manual\",\"user\":\"[anonymous]\",\"viewState\":{\"allImageSelection\":null,\"disableImageSelection\":true,\"disableStrategySelection\":false,\"hideClusterNamePreview\":false,\"imageId\":null,\"instanceProfile\":\"custom\",\"loadBalancersConfigured\":true,\"mode\":\"createPipeline\",\"readOnlyFields\":{},\"securityGroupsConfigured\":true,\"submitButtonLabel\":\"Add\",\"templatingEnabled\":true,\"useAllImageSelection\":false,\"usePreferredZones\":true,\"useSimpleCapacity\":true}}],\"name\":\"Deploy\",\"type\":\"deploy\"}],\"triggers\":[]}"
sudo curl -X POST --header "Content-Type: application/json" --header "*/*" -d "$CREATE_PIPELINE_DATA" "http://localhost:8084/pipelines"
echo "Demo pipelname $PIPELINE_NAME created"

echo "Spinnaker demo setup complete"

# TODO
# Re-enable keyvault
 



#!/bin/bash

set -e
set -o pipefail

SPINNAKER_CONFIG_DIR="/opt/spinnaker/config/azure_config/"
REPO="https://raw.githubusercontent.com/scotmoor/azure-quickstart-templates/basevm_param/azure-spinnaker/scripts/"
CRED_FILE="set-azure-credentials.sh"
INIT_FILE="configure_spinnaker.sh"
CRED_SOURCE=$REPO$CRED_FILE
INIT_SOURCE=$REPO$INIT_FILE
CRED_FULL_PATH=$SPINNAKER_CONFIG_DIR$CRED_FILE
INIT_FULL_PATH=$SPINNAKER_CONFIG_DIR$INIT_FILE

# pull down the latest credential setup script
sudo curl -o $CRED_FULL_PATH $CRED_SOURCE

# execute the credentials setup script

sudo bash $CRED_FULL_PATH

sudo curl -o $INIT_FULL_PATH $INIT_SOURCE

sudo bash $INIT_FULL_PATH 

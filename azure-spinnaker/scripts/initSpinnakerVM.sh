#!/bin/bash

set -e
set -o pipefail

SPINNAKER_CONFIG_DIR="/opt/spinnaker/config/azure_config/"
TARGET_FILE="set-azure-credentials.sh"
SOURCE="https://raw.githubusercontent.com/scotmoor/azure-quickstart-templates/master/azure-spinnaker/scripts/set-azure-credentials.sh"
FULL_PATH=$SPINNAKER_CONFIG_DIR$TARGET_FILE

# pull down the latest credential setup script
sudo curl -o $FULL_PATH $SOURCE

# execute the credentials setup script
sudo bash $FULL_PATH

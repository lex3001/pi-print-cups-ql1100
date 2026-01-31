#!/bin/bash

# Load configuration
CONFIG_FILE="$(dirname "$0")/deploy_config.sh"
if [ ! -f "$CONFIG_FILE" ]; then
  echo "Configuration file not found: $CONFIG_FILE"
  exit 1
fi
source "$CONFIG_FILE"

# Ensure required variables are set
if [ -z "$REMOTE_USER" ] || [ -z "$REMOTE_HOST" ]; then
  echo "REMOTE_USER and REMOTE_HOST must be set in the configuration file."
  exit 1
fi

REMOTE_PATH="/etc/cups/ppd/Brother_QL1100.ppd"
LOCAL_FILE="$(dirname "$0")/Brother_QL1100.ppd"

# Backup the remote file
BACKUP_PATH="~/Brother_QL1100.ppd.bak.$(date +%Y%m%d%H%M%S)"
echo "Backing up remote file to $BACKUP_PATH"
ssh "$REMOTE_USER@$REMOTE_HOST" "cp $REMOTE_PATH $BACKUP_PATH"

# Copy the local file to a temporary location on the remote machine
TEMP_PATH="/tmp/Brother_QL1100.ppd"
echo "Copying $LOCAL_FILE to $REMOTE_USER@$REMOTE_HOST:$TEMP_PATH"
scp "$LOCAL_FILE" "$REMOTE_USER@$REMOTE_HOST:$TEMP_PATH"

# Move the file to the target location with sudo
echo "Moving $TEMP_PATH to $REMOTE_PATH with sudo"
ssh "$REMOTE_USER@$REMOTE_HOST" "sudo mv $TEMP_PATH $REMOTE_PATH"

# Restart the CUPS service on the Raspberry Pi
echo "Restarting CUPS service on $REMOTE_HOST"
ssh "$REMOTE_USER@$REMOTE_HOST" "sudo systemctl restart cups"

if [ $? -eq 0 ]; then
  echo "Deployment successful."
else
  echo "Deployment failed."
  exit 1
fi
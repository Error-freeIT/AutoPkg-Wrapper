#!/bin/bash

# Version 1.0 (11/10/2014)

# This script automates the process of moving the
# AutoPkg Wrapper script and LaunchDaemon into place.

SCRIPT_DIR="/Library/Scripts/AutoPkg Wrapper"
SCRIPT_PATH="${SCRIPT_DIR}/autopkgwrapper.sh"
LAUNCHDAEMON_PATH="/Library/LaunchDaemons/au.com.errorfreeit.autopkgwrapper.plist"

# Check the script is being run by root.
if [[ $EUID -ne 0 ]]
then
   echo "Error: This script must be run as root." 
   exit 1
fi

# Create the AutoPkg Wrapper directory.
if [[ ! -d "$SCRIPT_DIR" ]]
then
	mkdir "$SCRIPT_DIR"
fi

# Copy the autopkgwrapper.sh script into place.
cp autopkgwrapper.sh "$SCRIPT_PATH"

if [[ $? -eq 0 ]]
then
	echo "Success: AutoPkg Wrapper script copied into place."
else
	echo "Error: Unable to copy autopkgwrapper.sh to: ${SCRIPT_DIR}"
	exit 1
fi

# Clear any extended permission attributes.
/usr/bin/xattr -c "$SCRIPT_PATH"

# Copy the autopkgwrapper LAUNCHDAEMON_PATH into place.
cp au.com.errorfreeit.autopkgwrapper.plist "$LAUNCHDAEMON_PATH"

if [[ $? -eq 0 ]]
then
	echo "Success: AutoPkg Wrapper LauchDaemon copied into place."
else
	echo "Error: Unable to copy au.com.errorfreeit.autopkgwrapper.plist to $LAUNCHDAEMON_PATH"
	exit 1
fi

# Correct the LaunchDaemon's file permissions.
/usr/bin/xattr -c "$LAUNCHDAEMON_PATH"
chmod 644 "$LAUNCHDAEMON_PATH"

# To automate triggering of the AutoPkg script load the LAUNCHDAEMON_PATH.
launchctl load "$LAUNCHDAEMON_PATH"

if [[ $? -eq 0 ]]
then
	echo "Success: AutoPkg Wrapper LauchDaemon enabled."
else
	echo "Error: Unable to load LaunchDaemon."
	exit 1
fi

# Configure the script by setting the ACCOUNT_NAME value to equal the account
# containing the recipe overrides and update the EMAIL_FROM and EMAIL_TO addresses.
/usr/bin/nano "$SCRIPT_PATH"
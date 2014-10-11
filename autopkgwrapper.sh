#!/bin/bash

# Version 1.0 (11/10/2014)

# This script should be saved to /Library/Scripts/AutoPkg Wrapper/
# and the com.errorfreeit.autopkgwrapper LaunchDaemon to /Library/LaunchDaemons/

# This script automates AutoPkg to check for software updates to items in ~/Library/AutoPkg/RecipeOverrides/.
# It also notifies the set contact via email in the event of a new package or if an issue is detected.

# The account name (a.k.a. username) containing recipe overrides.
ACCOUNT_NAME="admin"

# Email notification settings.
EMAIL_FROM="autopkgwrapper@errorfreeit.com.au"
EMAIL_TO="example@errorfreeit.com.au"
EMAIL_SUBJECT="AutoPkg Alert"

# If your email server requires internal SMTP autentication you can try sending
# notifications using AppleScript via an email account setup in Apple's Mail.app.
EMAIL_VIA_APPLESCRIPT=false


### Nothing below this line needs to be changed. ###

# Function containing the AppleScript method for sending emails.
# Note: The Mail AppleScript dictionary does not allow setting an EMAIL_FROM address.
function emailViaAppleScript() {	
/usr/bin/osascript <<APPLESCRIPT
	set emailSubject to "$1"
	set emailTo to "$2"
	set logFile to "$3"
	set emailContent to (do shell script "cat " & quoted form of (logFile))
	
	tell application "Mail"
		set emailMessage to make new outgoing message with properties {subject:emailSubject, content:emailContent}
		
		tell emailMessage
			make new to recipient with properties {address:emailTo}
			send
		end tell
	end tell
APPLESCRIPT
}

# Check this script is being run with root privileges.
if [[ $EUID -ne 0 ]]
then
   echo "Error: This script must be run with root privileges. Try adding sudo to the beginning of your command." 
   exit 1
fi

# Strings the contact should be notified about regardless of whether a IGNORE_STRING is detected.
ERROR_STRINGS="The following recipes failed|No valid recipe found for"

# Notify contact if the  output does not contain the standard "nothing new" string below.
IGNORE_STRINGS="Nothing downloaded, packaged or imported."

# Get the home directory path of the specified user.
USER_HOME_DIR=$(dscl . -read /Users/${ACCOUNT_NAME} | grep NFSHomeDirectory | awk '{print $NF}')

if [[ -z "$USER_HOME_DIR" ]]
then
	echo "Error: Could not find the home directory of account name: $ACCOUNT_NAME"
	exit 1
fi

# Set the user's recipe overrides directory.
RECIPE_OVERRIDE_DIR="${USER_HOME_DIR}/Library/AutoPkg/RecipeOverrides"

# Compile a list of recipe overrides.
for RECIPE_OVERRIDE in "$RECIPE_OVERRIDE_DIR"/*.recipe
do
	if [[ -f $RECIPE_OVERRIDE ]]
	then
		PARENT_RECIPE=$(basename "$RECIPE_OVERRIDE" .recipe)
		RECIPES+="$PARENT_RECIPE "
	fi
done

# Check that recipes list is not empty.
if [[ -z "$RECIPES" ]]
then
	echo "Error: No recipe overrides found in $RECIPE_OVERRIDE_DIR"
	exit 1
fi

# Temporary log file.
LOG_FILE="/tmp/autopkgwrapper.log"

# Check for repository updates.
sudo -u "$ACCOUNT_NAME" /usr/local/bin/autopkg repo-update all

# Run recipes and record output to a temporary log file.
echo "Checking for updates to: $RECIPES"
sudo -u "$ACCOUNT_NAME" /usr/local/bin/autopkg run -v $RECIPES MakeCatalogs.munki 2>&1 | /usr/bin/tee "$LOG_FILE"

# Check if output includes an error message or does not end with the standard "nothing new" message.
if /usr/bin/egrep -q "$ERROR_STRINGS" "$LOG_FILE" || ! /usr/bin/egrep -q "$IGNORE_STRINGS" "$LOG_FILE"
then
	echo "Important output detected, notifying contact."
	if $EMAIL_VIA_APPLESCRIPT
	then
		emailViaAppleScript "$EMAIL_SUBJECT" "$EMAIL_TO" "$LOG_FILE"	
	else
		/usr/bin/mail -s "$EMAIL_SUBJECT" "$EMAIL_TO" -F "AutoPkg Wrapper" -f "$EMAIL_FROM" < "$LOG_FILE"
	fi
fi

exit 0

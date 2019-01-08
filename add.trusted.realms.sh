#!/bin/sh

### REPLACE "GREENPLUM.LOCAL" with your realm! ###

currentUser=`ls -l /dev/console | awk {' print $3 '}`
prefExists=`cat /Users/$currentUser/Library/Application\ Support/Firefox/Profiles/*.default/prefs.js | grep "network.negotiate"`
twPrefExists=`cat /Users/$currentUser/Library/Application\ Support/Firefox/Profiles/*.default/prefs.js | grep "network.negotiate" | grep "GREENPLUM.LOCAL"`
isFirefoxRunning=`ps ax | grep "Firefox" | grep -v "+"`

# Add realm to Chrome
if [ ! -f /Users/"$currentUser"/Library/Preferences/com.google.Chrome.plist ]; then
  touch /Users/"$currentUser"/Library/Preferences/com.google.Chrome.plist
fi
defaults write /Users/"$currentUser"/Library/Preferences/com.google.Chrome AuthServerWhitelist "GREENPLUM.LOCAL"
chown "$currentUser":staff /Users/"$currentUser"/Library/Preferences/com.google.Chrome.plist

# Add/append realm to Firefox
if [[ $isFirefoxRunning ]]; then
osascript <<AppleScript
tell application "Finder"
  activate
  display dialog "Firefox is currently running. Firefox must be quit and this policy must be reinitiated for your browsing sessions to be trusted." default button "OK"
end tell
AppleScript
exit 1
elif [[ $prefExists != "" && $twPrefExists == "" ]]; then
  existingRealms=`cat /Users/$currentUser/Library/Application\ Support/Firefox/Profiles/*.default/prefs.js | grep "network.negotiate"| cut -d '"' -f 4`
  updatedRealms="$existingRealms, GREENPLUM.LOCAL"
  grep -v "network.negotiate" /Users/$currentUser/Library/Application\ Support/Firefox/Profiles/*.default/prefs.js > /tmp/tempKerbFile.js
  echo 'user_pref("network.negotiate-auth.trusted-uris", "'$updatedRealms'");' >> /tmp/tempKerbFile.js
  mv /tmp/tempKerbFile.js /Users/$currentUser/Library/Application\ Support/Firefox/Profiles/*.default/prefs.js
elif [[ $prefExists == "" ]]; then
  cat /Users/$currentUser/Library/Application\ Support/Firefox/Profiles/*.default/prefs.js > /tmp/tempKerbFile.js
  echo 'user_pref("network.negotiate-auth.trusted-uris", "GREENPLUM.LOCAL");' >> /tmp/tempKerbFile.js
  mv /tmp/tempKerbFile.js /Users/$currentUser/Library/Application\ Support/Firefox/Profiles/*.default/prefs.js
else
exit 0
fi

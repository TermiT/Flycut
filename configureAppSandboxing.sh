#!/bin/bash

appSandboxing=false
defineSandboxing=false

if [ "$1" == "YES" ]
then
	appSandboxing=true
	defineSandboxing=false
elif [ "$1" == "NO" ]
then
	appSandboxing=false
	defineSandboxing=false
elif [ "$1" == "SANDBOXING" ]
then
	appSandboxing=true
	defineSandboxing=true
else
	echo "Run with parameter YES or NO to enable or disable app sandboxing."
	echo "Or with parameter SANDBOXING to enable or app sandboxing and define SANDBOXING"
	echo "  in the prefix header."
	exit -1
fi

if [ "$defineSandboxing" == "true" ]
then
	sed -i '' 's|^//\(#define SANDBOXING\) *$|\1|' Flycut_Prefix.pch
	git add Flycut_Prefix.pch
else
	sed -i '' 's|^\(#define SANDBOXING\) *$|//\1|' Flycut_Prefix.pch
	git add Flycut_Prefix.pch
fi

for key in com.apple.security.app-sandbox com.apple.security.files.user-selected.read-write
do
	for entitlements in $(git grep -l -e ">$key<")
	do
		/usr/libexec/PlistBuddy -c "Set :$key $appSandboxing" "$entitlements"
		git add "$entitlements"
	done
done

for entitlements in $(git grep -l -e ">com.apple.security.automation.apple-events<" -- '*.entitlements')
do
	if [ "$defineSandboxing" == "false" ]
	then
		/usr/libexec/PlistBuddy -c "Set :com.apple.security.automation.apple-events true" "$entitlements"
	else
		/usr/libexec/PlistBuddy -c "Delete :com.apple.security.automation.apple-events" "$entitlements"
	fi

	git add "$entitlements"
done


for entitlements in $(git grep -l -e ">com.apple.security.temporary-exception.apple-events<" -- '*.entitlements')
do
	if [ "$appSandboxing" == "true" ] && [ "$defineSandboxing" == "false" ]
	then
		/usr/libexec/PlistBuddy -c "Set :com.apple.security.temporary-exception.apple-events com.apple.systemevents" "$entitlements"
	else
		/usr/libexec/PlistBuddy -c "Delete :com.apple.security.temporary-exception.apple-events" "$entitlements"
	fi

	git add "$entitlements"
done

git commit -m "App Sandbox $(if [ "$appSandboxing" == "true" ] ; then echo "ON" ; else echo "OFF" ; fi)$(if [ "$defineSandboxing" == "true" ] ; then echo " with define" ; fi)"


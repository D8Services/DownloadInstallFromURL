#!/bin/bash

###########################################################################################
## A quick and dirty script to download latest versions of software from a web URL
## This exists so that we do not have to package common software constantly, and stay up to date.
##
## Created by fred @ D8 Services LTD Hong Kong / Sydney
##
## No warranty is implied or supplied, and all use is stricly at your own risk.
## You can make any edits and redistributre at your own free will. just give me some credit.
###########################################################################################

###########################################################################################
# Tips on using this.....
#
# You can use this script in 3 ways..
#
# 1. Hardcode varibles into the fields indicated and run the script locally or with ARD
#
# 2. You can hardcode the values and make it a post install script in a packge file to be installed
#    any way that you want. ( Jamf users think patch managment )
#
# 3. You can run it from JAMF with dynamic variables passed as parameters to the script
#############################################################################################


## Lets generate a UUID so we have a unique id for un-important element names ( no need to change )
uniqueID=$(uuidgen)

## Lets log it all to a file, but where?
logfile="/Library/Management/Logs/ScriptInstallScript.log"

## This is the URL to pull from, should be $4 if using jamf
## NOTE if manually hardcoing a URL here please use single quotes around the url
## EXAMPLE: 'https://com.file.com/file.dmg'
url="$4"

## What type of file are we expecting to download. dmg or pkg, 
## should be pulled as $5 if using jamf
type="$5"

################################# Dodgey Hacks! ####################################################

## Special comand to install ( Dont use this normally ) 
## But you can specify the exact command required to perform this install action once the DMG is 
## downloaded and mounted. 
## For example, when you download flash player you need to execute an installer pkg that is 
## embeded inside an app bundle, inside the DMG itself
##. So you could run --
##. installer -pkg "/Volumes/Flash Player/Install Adobe Flash Player.app/Contents/Resources/Adobe Flash Player.pkg" -target /
##
## So here is where put the whole command in the special variable.
## Leave this blank unless required and if required, use variable 6 with jamf
special="$6"

################################# Action! ####################################################

## Make a file name out of our uuid and file type
dmgfile="${uniqueID}.${type}"

## if the log file path does not exist, lets create it.
if [[ ! -d "/Library/Management/Logs/" ]]; then
	mkdir -p "/Library/Management/Logs/"
fi

## log some header crap to the file
/bin/echo "--" >> ${logfile}
/bin/echo "`date`: Downloading latest version." >> ${logfile}

## Download the file using curl ( flat files only )
## We try to use generic links where possible, and follow the links with the L arg
/usr/bin/curl -k -L -s -o "/tmp/${dmgfile}" ${url}

/bin/echo "`date`: Installing ${dmgfile} ..." >> ${logfile}

## Some apps have spaces in the name.. so here you go.
IFS=$'\n'

## If we have a DMG, lets open it up and see whats inside
if [[ "${type}" == "dmg" ]]; then
	/bin/echo "`date`: Mounting installer disk image." >> ${logfile}
	volname="$(/usr/bin/hdiutil attach /tmp/${dmgfile} -nobrowse | tail -1 | awk -F"\t" '{print $3}')"

	## if we do not have any special command specified then loop through the content of the DMG
	if [[ "${special}" == "" ]]; then
		
		## iterate through the elements of the DMG looking for items
		for i in `ls "${volname}"`; do
			
			## found an app bundle, lets copy it to applications folder
			if [[ "$i" = *.app ]]; then
				ditto -rsrc "${volname}/$i" "/Applications/$i"
			fi
			
			## Inside the DMG we found a PKG, how nice of them. lets install it
			if [[ "$i" = *.pkg ]]; then
				installer -pkg "${volname}/$i" -target /
			fi
		done
	else
		## So there was something specified in special.. lets chuck that at the wall and
		## see if its sticks.
		bash -c "${special}"
	fi	
	
	## Clean up after DMG file mess
	/bin/echo "`date`: Unmounting installer disk image." >> ${logfile}
	/usr/bin/hdiutil detach $(/bin/df | /usr/bin/grep "${volname}" | awk '{print $1}') -quiet
	/bin/echo "`date`: Deleting disk image." >> ${logfile}
fi

## If its a PKG, lets just go for a straight install.. if every vendor just gave us pkg.. utopia
if [[ "${type}" == "pkg" ]]; then
	installer -pkg "/tmp/${dmgfile}" -target /
	/bin/echo "`date`: Deleting package file." >> ${logfile}
fi

## Clean up		
/bin/rm /tmp/"${dmgfile}"

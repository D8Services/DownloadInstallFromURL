#!/bin/bash

###########################################################################################
## A quick and dirty script to download latest versions of software from a web URL
## This exists so that we do not have to package common software constantly, and stay up to date.
##
## Created by fred @ D8 Services LTD Hong Kong / Sydney
##
## No warranty is implied or supplied, and all use is stricly at your own risk.
## You can make any edits and redistributre at your own free will. just give me some credit.
##
## Now updated with dual URL support for M1 Processors, You can provide a URL for normal downloads
## Which is required, and an Alt URL for M1 software versions. SCript will detect which version
## To download and install based on local processor type.
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

# Updates
# Tomos Tyler - D8 Service APR 2022 - Add ZIP download install and license agreement agreement to dmg

## Lets generate a UUID so we have a unique id for un-important element names ( no need to change )
uniqueID=$(uuidgen)


## Lets log it all to a file, but where?
logfile="/Library/Management/Logs/ScriptInstallScript.log"

## This is the URL to pull from, should be $4 if using jamf
## NOTE if manually hardcoing a URL here please use single quotes around the url
## EXAMPLE: 'https://com.file.com/file.dmg'
url="$4"

## This is the URL to pull Apple Silicon Versionf from, should be $5 if using jamf
## This is optional as universal URLs and Rosetta are a thing
## NOTE if manually hardcoing a URL here please use single quotes around the url
## EXAMPLE: 'https://com.file.com/file.dmg'
as_url="$5"

## What type of file are we expecting to download. dmg or pkg or zip, 
## should be pulled as $6 if using jamf
type="$6"

################################# Dodgey Hacks! ####################################################

## Special comand to install ( Dont use this normally ) 
## But you can specifiy the exact command required to perform ths install action once the DMG is 
## downloaded and mounted. 
## For example, when you download flash player you need to execute an installer pkg that is 
## embeded inside an app bundle, inside the DMG itself
##. So you run --
##. /usr/sbin/installer -pkg "/Volumes/Flash Player/Install Adobe Flash Player.app/Contents/Resources/Adobe Flash Player.pkg" -target /
##
## So here is where put the whole command in the special variable.
## Leave this blank unless required and if required, use variable 7 with jamf
special="$7"


################################# Quick Checks! ###############################################

# Moved to prevent errors for logging - TT
## if the log file path does not exist, lets create it.
if [[ ! -d "/Library/Management/Logs/" ]]; then
	mkdir -p "/Library/Management/Logs/"
fi

if [ -z "${url}" ]; then
	echo "No URL variable specified to download files from, kinda need that."
	echo "Read script comments for more usage information"
	exit 1
fi

if [ -z "${type}" ]; then
	echo "No Package Type variable specified to install, kinda need that."
	echo "Read script comments for more usage information"
	exit 1
fi

################################# Action! ####################################################
/bin/echo "`date`: -----------------" >> ${logfile}
/bin/echo "`date`: Starting.." >> ${logfile}

## Make a file name out of our uuid and file type
dmgfile="${uniqueID}.${type}"

## log some header stuff to the file
/bin/echo "--" >> ${logfile}
/bin/echo "`date`: Downloading source files now." >> ${logfile}

## See if we have passed an Apple Silicon link as an alternative dowload
if [ ! -z "${as_url}" ]; then
	/bin/echo "`date`: Alternate URL for Apple Silicon passed to script, checking local hardware." >> ${logfile}
	## Get the machine arch to see if we have apple silicon
	arch=$(/usr/bin/arch)
	
	## If we have Apple Silcion download from ALT URL 
	if [ "${arch}" == "arm64" ]; then
		/bin/echo "`date`: Apple silicon found, downloading from ${as_url}." >> ${logfile}
		## Download the file for Apple Silcion using curl ( flat files only )
		## We try to use generic links where possible, and follow the links with the L arg
		/usr/bin/curl -k -L -s -o "/tmp/${dmgfile}" ${as_url}
	
	## If its not, then assume intel x86 and download from main URL
	else
		/bin/echo "`date`: non arm64 processor found, downloading from ${url}." >> ${logfile}
		## Download the file using curl ( flat files only )
		## We try to use generic links where possible, and follow the links with the L arg
		/usr/bin/curl -k -L -s -o "/tmp/${dmgfile}" ${url}
	fi
else
	/bin/echo "`date`: Platform agnostic download from ${url}." >> ${logfile}
	## Download the file using curl ( flat files only )
	## We try to use generic links where possible, and follow the links with the L arg
	/usr/bin/curl -k -L -s -o "/tmp/${dmgfile}" ${url}
fi


/bin/echo "`date`: Attempting install from ${dmgfile} ..." >> ${logfile}

## Some apps have spaces in the name.. so here you go.
IFS=$'\n'

## If we have a DMG, lets open it up and see whats inside
if [[ "${type}" == "dmg" ]]; then
	/bin/echo "`date`: Mounting installer disk image." >> ${logfile}
	volname="$(echo "Y" | /usr/bin/hdiutil attach /tmp/${dmgfile} -nobrowse | tail -1 | awk -F"\t" '{print $3}')"

	## if we do not have any special command specified then loop through the content of the DMG
	if [[ "${special}" == "" ]]; then
		
		## iterate through the elements of the DMG looking for items
		for i in `ls "${volname}"`; do
			
			## found an app bundle, lets copy it to applications folder
			if [[ "$i" = *.app ]]; then
				/bin/echo "`date`: Copying files to Applications Folder" >> ${logfile}
				ditto -rsrc "${volname}/$i" "/Applications/$i"
			fi
			
			## Inside the DMG we found a PKG, how nice of them. lets install it
			if [[ "$i" = *.pkg ]]; then
				/bin/echo "`date`: Installing PKG from inside of the DMG" >> ${logfile}
				installer -pkg "${volname}/$i" -target /
			fi
		done
	else
		## So there was something specified in special.. lets chuck that at the wall and
		## see if its sticks.
		/bin/echo "`date`: Special install - Executing  ${special}" >> ${logfile}
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

## If its a ZIP, lets expand the file to see whats inside 
if [[ "${type}" == "zip" ]]; then
	# Lets look inside the zip to see what we have.
	zipAppName=$(unzip -l  "/tmp/${dmgfile}" | egrep "^([^/]*/?){1}$" | sed -n 3p | xargs -n 1 basename | tail -1)
	
	zipExtension="${zipAppName##*.}"
	zipFilename="${zipAppName%.*}"
	if [[ "$zipExtension" == "app" ]];then
		/bin/echo "`date`: Identified item \"${filename}\", installing." >> ${logfile}
		unzip /tmp/${dmgfile} -d /Applications/
	else
		/bin/echo "`date`: Identified item \"${$zipAppName}\", but no handler created as yet." >> ${logfile}
	fi
	/bin/echo "`date`: Deleting package file." >> ${logfile}
fi

## Clean up		
/bin/rm /tmp/"${dmgfile}"

/bin/echo "`date`: Install completed" >> ${logfile}
/bin/echo "`date`: -----------------" >> ${logfile}

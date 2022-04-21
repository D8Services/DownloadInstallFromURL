# DownloadInstallFromURL
## A quick script to download latest versions of software from a web URL
 This exists so that we do not have to package common software constantly, and stay up to date.

 Created by fred @ D8 Services LTD Hong Kong / Sydney

 No warranty is implied or supplied, and all use is stricly at your own risk.
 You can make any edits and redistributre at your own free will. just give me some credit.

 Now updated with dual URL support for M1 Processors, You can provide a URL for normal downloads
 Which is required, and an Alt URL for M1 software versions. SCript will detect which version
 To download and install based on local processor type.
 
 Now updated with support for zip files deployment packages

 Tips on using this.....

 You can use this script in 3 ways..

 1. Hardcode varibles into the fields indicated and run the script locally or with ARD

 2. You can hardcode the values and make it a post install script in a packge file to be installed
    any way that you want. ( Jamf users think patch managment )

 3. You can run it from JAMF with dynamic variables passed as parameters to the script

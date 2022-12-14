# AzureVMCreation
Store for my Azure Front End to Create Azure Infra Objects
1. Download the Zip file from repo
2. Extract the zip to a folder on the target machine (all files must reside in the same folder)
3. Populate the paramaters in VMCreationParams.json
4. Open a command prompt (powershell or Command shell) as an admin
5. Change directories to the directory created in step 2
6. run the LaunchLabHydration.ps1 file from command prompt

- You may need to set your Powershell execution policy to allow an unsigned to script to run
- Set-executionpolicy -executionpolicy bypass
- Install-Module Az
- Install-Module AzureAD

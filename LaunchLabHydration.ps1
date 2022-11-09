$params = Get-Content .\VMCreationParams.json -raw | ConvertFrom-Json -ErrorAction SilentlyContinue
$AzureUserName = $params.UserName
$TenantName = $params.TenantName
$HighRes = $params.HighRes
$LocalAdminName = $params.AdminName
$LocalPassword = $params.AdminPWD

.\LabHydration_V1.6.ps1 -AzureUserName $AzureUserName -TenantName $TenantName -HighRes $HighRes -LocalAdminName $LocalAdminName -LocalPassword $LocalPassword
<#
If you receive error Get-AzLocation : Your Azure credentials have not been set up or have expired, please run Connect-AzAccount to set up your Azure credentials.
SharedTokenCacheCredential authentication unavailable. Token acquisition failed for user ITAdmin@promite.onmicrosoft.com. Ensure that you have authenticated with a developer tool that supports Azure single sign on

This means that you have never authenticated with this device in your tenant. You will need to run Connect-AzAccount -UseDeviceAuthentication
WARNING: To sign in, use a web browser to open the page https://microsoft.com/devicelogin and enter the code provided to authenticate
#>

### Adding Visual Styles to allow for objects to have rounded corners
using assembly System.Windows.Forms
using namespace System.Windows.Forms
using namespace System.Drawing

### Install-Module Az prior to launch
### Install-Module AzureAD
### Setting Launch Params
param(
[parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$LocalAdminName,
[parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$LocalPassword,
[parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$AzureUserName,
[parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][String]$TenantName,
[parameter(Mandatory=$true)][ValidateNotNullOrEmpty()][ValidateSet("True", "False")][String]$HighRes
)

### Enable-AzureRMAlias allows for Legacy AzureRM Cmdlets to be used
Enable-AzureRMAlias

#$ErrorActionPreference = "SilentlyContinue"
$CurrentDirectory = $PSScriptRoot
$TitleICO = New-Object system.drawing.icon ("$CurrentDirectory\MSLogo.ico")

### Always Add These to PowerShell Forms
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName PresentationFramework
[System.Windows.Forms.Application]::EnableVisualStyles()
### If HighRes Screen is set the form multiplier will be reset to accomodate a larger size
If($HighRes -eq "True")
{
    $Global:XMultiplier=2
    $Global:yMultiplier=2
}
Else
{
    $Global:XMultiplier=1
    $Global:yMultiplier=1
}
$Global:VMPrefix = $null
### Setting Up PowerShell Form
$Global:Form = New-Object System.Windows.Forms.Form    
$Global:Form.Size = New-Object System.Drawing.Size((800*$Global:XMultiplier),(1000*$Global:yMultiplier))  
$Global:Form.Text = "Lab Hydration Utility"  
$Global:ClientName = "Microsoft"
$Global:Form.BackColor = "#000000"
$Global:Form.Icon = $TitleICO
$BackImage = [System.Drawing.Image]::Fromfile("$CurrentDirectory\NinjaCatBackground.png")
$Global:Form.BackgroundImage = $BackImage
$Global:Form.FormBorderStyle = "None"
$InfraCompnentsBackWindow = New-Object System.Windows.Forms.TextBox

### Since no border is selected - I am making the form object draggable with the below code
$global:dragging = $false
$global:mouseDragX = 0
$global:mouseDragY = 0

# set the 'dragging' flag and capture the current mouse position
$global:Form.Add_MouseDown({$global:dragging = $true;$global:mouseDragX = [System.Windows.Forms.Cursor]::Position.X - $form.Left;$global:mouseDragY = [System.Windows.Forms.Cursor]::Position.Y -$form.Top})

# move the form while the mouse is depressed (i.e. $global:dragging -eq $true)
$global:Form.Add_MouseMove({if($global:dragging)
  {
    $screen = [System.Windows.Forms.Screen]::PrimaryScreen.WorkingArea;$currentX = [System.Windows.Forms.Cursor]::Position.X;$currentY = [System.Windows.Forms.Cursor]::Position.Y;[int]$newX = [Math]::Min($currentX - $global:mouseDragX, $screen.Right - $form.Width)
    [int]$newY = [Math]::Min($currentY - $global:mouseDragY, $screen.Bottom - $form.Height);$global:Form.Location = New-Object System.Drawing.Point($newX, $newY)
  }
})

# stop dragging the form
$global:Form.Add_MouseUp({$global:dragging = $false})


### Authenticating to Graph / Tenant
function Get-AuthToken
{
    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $true)]
        $User
    )

    $userUpn = New-Object "System.Net.Mail.MailAddress" -ArgumentList $User
    $tenant = $userUpn.Host

    Write-Host "Checking for AzureAD module..."

    $AadModule = Get-Module -Name "AzureAD" -ListAvailable
    if ($AadModule -eq $null)
    {
        Write-Host "AzureAD PowerShell module not found, looking for AzureADPreview"
        $AadModule = Get-Module -Name "AzureADPreview" -ListAvailable
    }

    if ($AadModule -eq $null) {
        write-host
        write-host "AzureAD Powershell module not installed..." -f Red
        write-host "Install by running 'Install-Module AzureAD' or 'Install-Module AzureADPreview' from an elevated PowerShell prompt" -f Yellow
        write-host "Script can't continue..." -f Red
        write-host
        exit
    }

    # Getting path to ActiveDirectory Assemblies
    # If the module count is greater than 1 find the latest version

    if ($AadModule.count -gt 1) {
        $Latest_Version = ($AadModule | select version | Sort-Object)[-1]
        $aadModule = $AadModule | ? { $_.version -eq $Latest_Version.version }
        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    }

    else {
        $adal = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.dll"
        $adalforms = Join-Path $AadModule.ModuleBase "Microsoft.IdentityModel.Clients.ActiveDirectory.Platform.dll"
    }

    [System.Reflection.Assembly]::LoadFrom($adal) | Out-Null
    [System.Reflection.Assembly]::LoadFrom($adalforms) | Out-Null

    $clientId = "d1ddf0e4-d672-4dae-b554-9d5bdfd93547"
    $redirectUri = "urn:ietf:wg:oauth:2.0:oob"
    $resourceAppIdURI = "https://graph.microsoft.com"
    $authority = "https://login.microsoftonline.com/$Tenant"

    try {
        $authContext = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext" -ArgumentList $authority
        # https://msdn.microsoft.com/library/azure/microsoft.identitymodel.clients.activedirectory.promptbehavior.aspx
        # Change the prompt behaviour to force credentials each time: Auto, Always, Never, RefreshSession
        $platformParameters = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.PlatformParameters" -ArgumentList "Auto"
        $userId = New-Object "Microsoft.IdentityModel.Clients.ActiveDirectory.UserIdentifier" -ArgumentList ($User, "OptionalDisplayableId")
        $authResult = $authContext.AcquireTokenAsync($resourceAppIdURI, $clientId, $redirectUri, $platformParameters, $userId).Result
        # If the accesstoken is valid then create the authentication header
        if ($authResult.AccessToken) {
            # Creating header for Authorization token
            $authHeader = @{
                'Content-Type' = 'application/json'
                'Authorization' = "Bearer " + $authResult.AccessToken
                'ExpiresOn' = $authResult.ExpiresOn
            }
            return $authHeader
        }
        else {
            Write-Host
            Write-Host "Authorization Access Token is null, please re-run authentication..." -ForegroundColor Red
            Write-Host
            break
        }
    }
    catch {
        write-host $_.Exception.Message -f Red
        write-host $_.Exception.ItemName -f Red
        write-host
        break
    }   
}

### Connecting to Azure
$Global:authToken = Get-AuthToken -User $AzureUserName
### Connect-AzureAD is using the Auth token created in the line above
Connect-AzureAD -AccountId $AzureUserName

######### Creating Form Objects #########
### Creating Label Objects
$NewRGLabel = New-Object System.Windows.Forms.Label
$NewVNetLabel = New-Object System.Windows.Forms.Label
$NewSubnetLabel = New-Object System.Windows.Forms.Label
$NewRGNameLabel = New-Object System.Windows.Forms.Label
$NewVNetNameLabel = New-Object System.Windows.Forms.Label 
$NewVNetDescriptionLabel = New-Object System.Windows.Forms.Label
$NewSubnetDescriptionLabel = New-Object System.Windows.Forms.Label
$NewSubnetNameLabel = New-Object System.Windows.Forms.Label
$NewDCCBLabel = New-Object System.Windows.Forms.Label
$NewMSCBLabel = New-Object System.Windows.Forms.Label
$NewWSCBLabel = New-Object System.Windows.Forms.Label
$NewDCCompNameLabel = New-Object System.Windows.Forms.Label
$NewMSCompNameLabel = New-Object System.Windows.Forms.Label
$NewWSCompNameLabel = New-Object System.Windows.Forms.Label
$NewDCCountLabel = New-Object System.Windows.Forms.Label
$NewMSCountLabel = New-Object System.Windows.Forms.Label
$NewWSCountLabel = New-Object System.Windows.Forms.Label
$NewDCImageLabel = New-Object System.Windows.Forms.Label
$NewMSImageLabel = New-Object System.Windows.Forms.Label
$NewWSImageLabel = New-Object System.Windows.Forms.Label
$NewDCMachineTypeLabel = New-Object System.Windows.Forms.Label
$NewMSMachineTypeLabel = New-Object System.Windows.Forms.Label
$NewWSMachineTypeLabel = New-Object System.Windows.Forms.Label

### Creating Drop Down Menu
$AzureSubscriptionsDropdown = New-Object System.Windows.Forms.ComboBox
$AzureResourceGroupDropdown = New-Object System.Windows.Forms.ComboBox
$AzureVirtualNetworkDropdown = New-Object System.Windows.Forms.ComboBox
$AzureVirtualSubnetDropdown = New-Object System.Windows.Forms.ComboBox
$AzureLocationDropdown = New-Object System.Windows.Forms.ComboBox
$AzureDMachineDropdown = New-Object System.Windows.Forms.ComboBox
$AzureBMachineDropdown = New-Object System.Windows.Forms.ComboBox
$AzureLocationDropDown = New-Object System.Windows.Forms.ComboBox
$NewVNetDropDown = New-Object System.Windows.Forms.ComboBox
$NewDCImageDropDown = New-Object System.Windows.Forms.ComboBox
$NewDCMachineTypeDropDown = New-Object System.Windows.Forms.ComboBox
$NewMSImageDropDown = New-Object System.Windows.Forms.ComboBox
$NewMSMachineTypeDropDown = New-Object System.Windows.Forms.ComboBox
$NewWSImageDropDown = New-Object System.Windows.Forms.ComboBox
$NewWSMachineTypeDropDown = New-Object System.Windows.Forms.ComboBox
$NewSubnetDropDown = New-Object System.Windows.Forms.ComboBox
$LabMachineTypeDropdown = New-Object System.Windows.Forms.ComboBox

### Creating Text Box Objects
$ResourceGroupNameTextBox = New-Object System.Windows.Forms.TextBox
$NewVNetNameTextBox = New-Object System.Windows.Forms.TextBox
$NewSubnetNameTextBox = New-Object System.Windows.Forms.TextBox
$NewDCCountTextBox = New-Object System.Windows.Forms.TextBox
$NewMSCountTextBox = New-Object System.Windows.Forms.TextBox
$NewWSCountTextBox = New-Object System.Windows.Forms.TextBox
$NewDCNameTextBox = New-Object System.Windows.Forms.TextBox
$NewMSNameTextBox = New-Object System.Windows.Forms.TextBox
$NewWSNameTextBox = New-Object System.Windows.Forms.TextBox
$NewComponentInfraBackground = New-Object System.Windows.Forms.TextBox
$NewMachineCreationBackground = New-Object System.Windows.Forms.TextBox
$MachineCreationStatusTextBox = New-Object System.Windows.Forms.TextBox
 
### Creating Buttons
$CreateNewRGButton = New-Object System.Windows.Forms.Button 
$VerifyNewRGButton = New-Object System.Windows.Forms.Button 
$CreateNewVNetButton = New-Object System.Windows.Forms.Button 
$VerifyNewVNetButton = New-Object System.Windows.Forms.Button 
$VerifyNewSubnetButton = New-Object System.Windows.Forms.Button
$CreateNewSubnetButton = New-Object System.Windows.Forms.Button
$VerifyNewDCButton = New-Object System.Windows.Forms.Button
$CreateNewDCButton = New-Object System.Windows.Forms.Button
$VerifyNewMSButton = New-Object System.Windows.Forms.Button
$CreateNewMSButton = New-Object System.Windows.Forms.Button
$VerifyNewWSButton = New-Object System.Windows.Forms.Button
$CreateNewWSButton = New-Object System.Windows.Forms.Button
$MinButton = New-Object System.Windows.Forms.Button
$NormalButton = New-Object System.Windows.Forms.Button
$ExitButton = New-Object System.Windows.Forms.Button

### Creating Checkbox Objects
$NewRGCheckBox = new-object System.Windows.Forms.checkbox
$NewVnetCheckBox = new-object System.Windows.Forms.checkbox
$NewSubNetCheckBox = new-object System.Windows.Forms.checkbox
$NewDCCheckBox = New-object System.Windows.Forms.checkbox
$NewMSCheckBox = New-object System.Windows.Forms.checkbox
$NewWSCheckBox = New-object System.Windows.Forms.checkbox

### Creating Prog Bar Objects
$Column1ProgressBar = New-Object System.Windows.Forms.ProgressBar
$Column2ProgressBar = New-Object System.Windows.Forms.ProgressBar
$Column3ProgressBar = New-Object System.Windows.Forms.ProgressBar

### Creating PictureBox Objects
$InfraBackground = new-object Windows.Forms.PictureBox
$MachineCreationBackground = new-object Windows.Forms.PictureBox
$MachineCreationStatusBackground = new-object Windows.Forms.PictureBox
$MachineCreationStatusWhiteBackground = new-object Windows.Forms.PictureBox
$InfraStatusWhiteBackground = new-object Windows.Forms.PictureBox
$TopBarImage = new-object Windows.Forms.PictureBox
$ResourceGroupCheckImage = new-object Windows.Forms.PictureBox
$VNetCheckImage = new-object Windows.Forms.PictureBox
$SubnetCheckImage = new-object Windows.Forms.PictureBox

######### Functions for Creating Form Objects #########

### Function to Create DropDown Menus
Function CreateDropDownMenus($DropdownObject,$PosX,$PosY,$BoxLen,$BoxHeight,$MenuHeight,$TextforFirstItem)
{
    $DropdownObject.Location = new-object System.Drawing.Size($PosX,$PosY)
    $DropdownObject.Size = new-object System.Drawing.Size($BoxLen,$BoxHeight)
    $DropdownObject.DropDownHeight = 300
    $DropdownObject.Enabled = $False
    $DropdownObject.Items.Add($TextforFirstItem)
    $DropdownObject.SelectedItem = $DropdownObject.Items[0]
    $DropdownObject.BringToFront()
    $DropdownObject.Font = New-Object System.Drawing.Font("Lucida Console",(9*$XMultiplier),[System.Drawing.FontStyle]::Regular)
    $DropdownObject.show()
    $Form.Controls.Add($DropdownObject)
}

### Function to Create Text Labels
Function CreateTextBoxLabel($TextBoxLabel,$PosX,$PosY,$BoxLen,$BoxHeight,$Title)
{
    $TextBoxLabel.Location = New-Object System.Drawing.Point($PosX,$PosY)
    $TextBoxLabel.Size = New-Object System.Drawing.Size($BoxLen,$BoxHeight)
    $TextBoxLabel.Text = $Title
    $TextBoxLabel.BringToFront()
    $TextBoxLabel.Show()
    #$TextBoxLabel.BackColor = "#00a3ee"
    $TextBoxLabel.BackColor = "#bcdaf6"
    #$TextBoxLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $Global:form.Controls.Add($TextBoxLabel)
}

### Function to Create Text Box 
Function CreateTextBoxObject($TextBoxObject,$PosX,$PosY,$BoxLen,$BoxHeight)
{
    #Write-host $BoxHeight
    $TextBoxObject.Location = New-Object System.Drawing.Point($PosX,$PosY)
    $TextBoxObject.Size = New-Object System.Drawing.Size($BoxLen,$BoxHeight)
    $TextBoxObject.BringToFront()
    $TextBoxObject.show()
    $TextBoxObject.backcolor = "#ffffff"
    $Global:form.Controls.Add($TextBoxObject)
}

### Function to Create Check Box
Function CreateCheckBox($CheckBoxObject,$PosX,$PosY)
{
    $CheckBoxObject.Location = new-object System.Drawing.Size($PosX,$PosY)
    $CheckBoxObject.Size = new-object System.Drawing.Size(20,20)
    $CheckBoxObject.Checked = $False
    $CheckBoxObject.show()
    $CheckBoxObject.BringToFront()
    #$CheckBoxObject.BackColor = "#00a3ee"
    $CheckBoxObject.BackColor = "#bcdaf6"    
    $Form.Controls.Add($CheckBoxObject)
}

### Assumes Image File will be in same directory as script ----- Round Variable will be a yes / No
Function CreatePictureBox($PictureBoxObject,$PosX,$PosY,$Round,$ImageName)
{
    $PictureBoxImage = [System.Drawing.Image]::Fromfile("$CurrentDirectory\$ImageName")
    $PictureBoxObject.Location = New-Object System.Drawing.Size($PosX,$PosY)
    $PictureBoxObject.Size = New-Object System.Drawing.Size($PictureBoxImage.Width,$PictureBoxImage.Height)
    $PictureBoxObject.Image = $PictureBoxImage
    If($Round -eq "Yes"){RoundCorners $PictureBoxObject}
    $Global:Form.controls.add($PictureBoxObject)
}
### Function to Create Buttons
Function CreateButton($ButtonObject,$PosX,$PosY,$ButtonLen,$ButtonHeight,$ButtonText,$Type)
{  
    $ButtonObject.Location = New-Object System.Drawing.Size($PosX,$PosY) 
    $ButtonObject.Size = New-Object System.Drawing.Size($ButtonLen,$ButtonHeight) 
    #$ButtonObject.Font = $Global:High_DPIScale_Font
    $ButtonObject.Text = $ButtonText
    $ButtonObject.BringToFront()
    $ButtonObject.Backcolor = "#7eb801"
    #$ButtonObject.ForeColor = "#FFFFFF"
    $ButtonObject.FlatStyle = [system.windows.forms.FlatStyle]::Flat
    $ButtonObject.FlatAppearance.BorderColor = [System.Drawing.Color]::Gray
    $ButtonObject.FlatAppearance.BorderSize = (1*$XMultiplier)
    $ButtonObject.ImageAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $ButtonObject.show()
    If($Type -eq "Validate")
    {
        $ValidationButtonImage = [system.drawing.image]::FromFile("$CurrentDirectory\ResizedValidate.png")
        $ButtonObject.image = $ValidationButtonImage
    }
    If($Type -eq "Create")
    {
        $CreateButtonImage = [system.drawing.image]::FromFile("$CurrentDirectory\ResizedCreate.png")
        $ButtonObject.image = $CreateButtonImage
    }
    $ButtonObject.font = New-Object System.Drawing.Font("Calibri",(9*$XMultiplier),[System.Drawing.FontStyle]::Regular)
    $Form.Controls.Add($ButtonObject)
}

### Function to Create Buttons
Function CreateVMDisplayButton($ButtonObject,$PosX,$PosY,$ButtonLen,$ButtonHeight,$BackImage)
{  
    $ButtonObject.Location = New-Object System.Drawing.Size($PosX,$PosY) 
    $ButtonObject.Size = New-Object System.Drawing.Size($ButtonLen,$ButtonHeight) 
    $ButtonObject.ForeColor = "#FFFFFF"
    $ButtonObject.FlatStyle = [system.windows.forms.FlatStyle]::Flat
    $ButtonObject.ImageAlign = [System.Drawing.ContentAlignment]::MiddleCenter
    $ButtonObject.image = $BackImage
    $Global:MachineDetailForm.Controls.Add($ButtonObject)
    $ButtonObject.BringToFront()
    $ButtonObject.show()
}


####### Populating DropdownMenus #######
### Populating Resource Group DropDown -This change is initiated from a change in the subscription dropdown
Function SortDropDownMenu($DropdownObject)
{
    $DropdownObject.Enabled = $true
    $DropdownObject.Sorted = $true
    $DropdownObject.SelectedItem = $DropdownObject.Items[0]
}

Function ClearDropDownMenu($DropdownObject,$FirstLineText)
{
    $DropdownObject.Items.Clear()
    $DropdownObject.Items.Add($FirstLineText)
    $DropdownObject.SelectedItem = $DropdownObject.Items[0]
}

Function SubscriptionDropDownChange
{
    If($AzureSubscriptionsDropdown.SelectedIndex -gt 0)
    {
        $NewRGCheckBox.Enabled = $True
        $Global:SubscriptionName = $AzureSubscriptionsDropdown.SelectedItem
        Select-AzSubscription -subscription $Global:SubscriptionName

        ### Populating Azure Resource Groups
        ClearDropDownMenu $AzureResourceGroupDropdown "- Choose Azure Resource Group -"

        $AzureResourceGroups = Get-AZResourceGroup |select resourcegroupname,location
        ForEach($ResourceGroup in $AzureResourceGroups)
        {
            $ResourceGroupText = $ResourceGroup.ResourceGroupName + " (" + $ResourceGroup.Location + ")"
            $AzureResourceGroupDropdown.Items.Add($ResourceGroupText)
        }
        SortDropDownMenu $AzureResourceGroupDropdown
    }
    Else
    {
        $NewRGCheckBox.Enabled = $false
        ClearDropDownMenu $AzureResourceGroupDropdown "- Choose Azure Resource Group -"
    }
}


### Populating VNet Dropdown - Based on Resource Group Selection Changes
Function ResourceGroupChange
{
    If($AzureResourceGroupDropdown.SelectedIndex -gt 0)
    {
        $ResourceGroupCheckImage.Hide()
        $VNetCheckImage.Hide()
        $SubnetCheckImage.Hide()
        $NewVnetCheckBox.Enabled = $True
        [string]$ResourceGroup = $AzureResourceGroupDropdown.SelectedItem
        $LocationCount = $ResourceGroup.IndexOf(' (' )
        #$ResourceLocationLength = $ResourceGroup.Length - ($LocationCount + 11)
        $Global:ResourceGroupName = $ResourceGroup.Substring(0,$LocationCount)

        ### Populating Network Dropdown Info
        ClearDropDownMenu $AzureVirtualNetworkDropdown "- Choose Azure Virtual Network -"
         
        $AzureVirtualNetworks = Get-AzVirtualNetwork -WarningAction SilentlyContinue -ResourceGroupName $Global:ResourceGroupName
        ForEach($Network in $AzureVirtualNetworks)
        {
           $AzureVirtualNetworkDropdown.Items.Add($Network.Name)
        }
        SortDropDownMenu $AzureVirtualNetworkDropdown
        ### Setting this variable to track location change between functions
        #$Global:LastCheckResouceGroupLocation = $Global:ResourceGroupLocation
        $ResourceGroupCheckImage.Show()
    }
    Else
    {
        ClearDropDownMenu $AzureVirtualNetworkDropdown "- Choose Azure Virtual Network -"
    }
}

### VNet Network
Function NetworkGroupChange
{
    $VNetCheckImage.Hide()
    $SubnetCheckImage.Hide()
    IF($AzureVirtualNetworkDropdown.SelectedIndex -gt 0)
    {
        $NewSubNetCheckBox.Enabled = $True
        ClearDropDownMenu $AzureVirtualSubnetDropdown "Choose Subnet"
        $AzureVirtualNetworks = Get-AzVirtualNetwork
        ForEach($Network in $AzureVirtualNetworks)
        {
            $AZResourceGroup = $Network.ResourceGroupName 
            $AZResrouceName = $Network.Name
            If($AZResrouceName -eq $AzureVirtualNetworkDropdown.SelectedItem)
            {
                $Location = $Network.Location
                $VNetPreFix = $Network.AddressSpace.AddressPrefixes
                #$VNET = Get-AzVirtualNetwork -ResourceGroupName $AZResourceGroup -Name $AZResrouceName
                $SubnetList = $Network.Subnets
                ForEach($Prefix in $SubnetList)
                {
                    $SubnetText = $Prefix.Name + " (" + $Prefix.AddressPrefix + ")"
                    $AzureVirtualSubnetDropdown.Items.Add($SubnetText)
                }
            }
        }
        SortDropDownMenu $AzureVirtualSubnetDropdown
        $VNetCheckImage.Show()
    }
    Else
    {
        ClearDropDownMenu $AzureVirtualSubnetDropdown "Choose Subnet"
    }
}

### Creating Windows Gallery Images Lists
Function GetGalleryImages($Location)
{
    $Global:DesktopImageArray = @()
    $Global:ServerImageArray = @()
    $Win10Image = Get-AzVMImageSku -Location $Location -PublisherName MicrosoftWindowsDesktop -Offer Windows-10 | Where-Object{$_.Skus -like "*ent-g2"} | select skus
    $Win11Image = Get-AzVMImageSku -Location $Location -PublisherName MicrosoftWindowsDesktop -Offer Windows-11 | Where-Object{$_.Skus -like "*ent"} | select skus
    ### Contains 2012,2012R2,206,2019
    $Server201xImage = Get-AzVMImageSku -Location $Location -PublisherName MicrosoftWindowsserver -Offer WindowsServer | Where-Object{$_.Skus -like "*datacenter-gensecond"} | select skus
    ### Contains Server 2022 and forward images
    $Server202xImage = Get-AzVMImageSku -Location $Location -PublisherName MicrosoftWindowsserver -Offer WindowsServer | Where-Object{$_.Skus -like "*datacenter-g2"} | select skus
    ForEach($SKU in $Win10Image){$Global:DesktopImageArray += $SKU.Skus}
    ForEach($SKU in $Win11Image){$Global:DesktopImageArray += $SKU.Skus}
    ForEach($SKU in $Server201xImage){$Global:ServerImageArray += $SKU.Skus}
    ForEach($SKU in $Server202xImage){$Global:ServerImageArray += $SKU.Skus}
}

### Getting Azure Machine Types
Function GetAZMachinesTypes($Location)
{
    $AZMachineArray = Get-AzVmSize -Location $Location
    $Global:DClassTable = @{}
    $Global:BClassTable = @{}
    ForEach($MachineType in $AZMachineArray)
    {
        ### Creating D Class Machine Array
        IF($MachineType.Name -like "Standard_D*V5" -or $MachineType.Name -like "Standard_D*V2")
        {
            [string]$Name =  $MachineType.Name
            [string]$RAM = $MachineType.MemoryInMB
            [string]$CPU = $MachineType.NumberOfCores
             $Global:DClassTable += @{$Name = [PSCustomObject]@{RAM=$RAM;CPU=$CPU}}
        }

        ### Creating B Class Machine Array
        IF($MachineType.Name -like "Standard_B*")
        {
            [string]$Name =  $MachineType.Name
            [string]$RAM = $MachineType.MemoryInMB
            [string]$CPU = $MachineType.NumberOfCores
            $Global:BClassTable += @{$Name = [PSCustomObject]@{RAM=$RAM;CPU=$CPU}}
        }
    }
}

### Getting Azure DataCenter Locations
Function GetAZLocations
{
    CreateDropDownMenus $AzureLocationDropDown (440*$XMultiplier) (170*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier) (300*$XMultiplier) "- Choose AZ DataCenter Location -"
    $AzureLocationDropDown.Hide()
    $AZLocationArray = Get-AzLocation | Sort-Object DisplayName
    $Global:LocationTable = @{}
    ForEach($GeoLocation in $AZLocationArray)
    {
        [string]$Name = $GeoLocation.DisplayName
        [string]$LocationString = $GeoLocation.Location
        $Global:LocationTable += @{$Name = [PSCustomObject]@{LOCATION=$LocationString}}
        $AzureLocationDropDown.Items.Add($Name)
        SortDropDownMenu $AzureLocationDropDown
    }
    Write-Host $Global:LocationTable["West US 2"].LOCATION
    #Write-Host $BClassTable.Name
}

#### Creating New ResourceGroup form Objects - From CheckBox Click
Function CreateNewRGObects($checkstate)
{
    If($checkstate -eq "Checked")
    {
        $AzureVirtualNetworkDropdown.Enabled = $False
        $NewVnetCheckBox.Enabled = $False
        $AzureResourceGroupDropdown.Enabled = $false
        #CreateTextBoxObject $NewComponentInfraBackground (420*$XMultiplier) (80*$yMultiplier) (300*$XMultiplier) (230*$XMultiplier)
        CreateTextBoxLabel $NewRGNameLabel (440*$XMultiplier) (100*$yMultiplier) (200*$xMultiplier) (15*$yMultiplier) "Resource Group Name"
        CreatePictureBox $InfraStatusWhiteBackground (400*$xMultiplier) (80*$yMultiplier) "Yes" "InfraBackWallPaperWhite.png"
        $InfraStatusWhiteBackground.BringToFront()
        $InfraStatusWhiteBackground.Show()
        CreateTextBoxObject $ResourceGroupNameTextBox (440*$XMultiplier) (130*$yMultiplier) (200*$XMultiplier) (20*$XMultiplier)
        CreateButton $VerifyNewRGButton (440*$XMultiplier) (200*$yMultiplier) (200*$XMultiplier) (40*$xMultiplier) "Verify Resource Group" "Validate"
        CreateButton $CreateNewRGButton (440*$XMultiplier) (250*$yMultiplier) (200*$XMultiplier) (40*$xMultiplier) "Create Resource Group" "Create"
        $VerifyNewRGButton.FlatAppearance.BorderSize = 0
        $CreateNewRGButton.FlatAppearance.BorderSize = 0
        $VerifyNewRGButton.Name = "Test-012"
        RoundCorners $VerifyNewRGButton
        RoundCorners $CreateNewRGButton
        $NewRGNameLabel.BackColor = "#ffffff"
        $NewComponentInfraBackground.Multiline = $True
        $NewComponentInfraBackground.BringToFront()
        $ResourceGroupNameTextBox.BringToFront()
        $NewComponentInfraBackground.ReadOnly = $TRue
        $VerifyNewRGButton.BringToFront()
        $CreateNewRGButton.BringToFront()
        $NewRGNameLabel.BringToFront()
        $CreateNewRGButton.Enabled = $False
        $CreateNewRGButton.BackColor = "#aba7a7"
        $NewRGNameLabel.Show()
        $ResourceGroupNameTextBox.show()
        $AzureLocationDropDown.Enabled = $true
        $AzureLocationDropDown.BringToFront()
        $AzureLocationDropDown.Show()
        $CreateNewRGButton.Show()
        $VerifyNewRGButton.Show()
    }
    Else
    {
        $NewRGNameLabel.hide()
        $ResourceGroupNameTextBox.Clear()
        $ResourceGroupNameTextBox.Hide()
        $AzureLocationDropDown.Enabled = $false
        $AzureLocationDropDown.Hide()
        $AzureLocationDropDown.SelectedIndex[0]
        $AzureResourceGroupDropdown.Enabled = $true
        $CreateNewRGButton.hide()
        $VerifyNewRGButton.hide()
        $InfraStatusWhiteBackground.Hide()
        $NewComponentInfraBackground.Hide()
        Write-Host $VerifyNewRGButton.Name
    } 

}

Function VerifyRG
{
    ### Resetting Items to enabled state
    $ResourceGroupNameTextBox.Enabled = $true
    $CreateNewRGButton.Enabled = $False
    $VerifyNewRGButton.Enabled = $True

    $ValidationPassed = $False
    If($ResourceGroupNameTextBox.Text -NE "")
    {
        If(Get-AzResourceGroup -Name $ResourceGroupNameTextBox.Text -ErrorAction SilentlyContinue)
        {
            
            [System.Windows.MessageBox]::Show("The Resource Group " + $ResourceGroupNameTextBox.Text + " already exists. Press OK to try again.",'Resource Group Validation','OK','Error')
        }
        else
        {
            ### Checking for special Characters and Spaces
            If(($ResourceGroupNameTextBox.Text -match '[^a-zA-Z0-9^-]') -eq $True)
            {
                [System.Windows.MessageBox]::Show("The Resource Group cannot contain spaces or special characters.`nPress OK to try again.",'Location Validation','OK','Error')
            }
            Else
            {
                If($AzureLocationDropDown.SelectedIndex -eq 0)
                {
                    $LocationSelectionMsgText = "Location is not selected, press OK to continue and select a Location."
                    [System.Windows.MessageBox]::Show( $LocationSelectionMsgText,'Location Validation','OK','Error')
                }
                Else
                {
                    $LocationSelectionMsgText = "Verify that " + $AzureLocationDropDown.Text + " is the correct location."
                    $ValidationPassed = [System.Windows.MessageBox]::Show($LocationSelectionMsgText + "`nThe Resource Group " + $ResourceGroupNameTextBox.Text + " has passed Validation. Press Yes to Continue or No to Go Back",'Resource Group Validation','YesNo','Question')
                }
            }
        }
    }
    Else
    {
        [System.Windows.MessageBox]::Show("The Resource Group Name Field cannot be left bank. Press OK to try again.",'Resource Group Validation','OK','Error')
    }
    
    If($ValidationPassed -eq "Yes")
    {
        $VerifyNewRGButton.Enabled = $False
        $CreateNewRGButton.Enabled = $true
        $ResourceGroupNameTextBox.Enabled = $False
        $VerifyNewRGButton.BackColor = "#aba7a7"
        $CreateNewRGButton.BackColor = "#7eb801"
    }
    Else
    {
        $ResourceGroupNameTextBox.Enabled = $true
        $CreateNewRGButton.Enabled = $False
    }
}

Function CreateNewRG
{
    [String]$RGNameText = $ResourceGroupNameTextBox.Text

    New-AzResourceGroup -Name $RGNameText -Location $AzureLocationDropDown.Text
    If(Get-AzResourceGroup -Name $ResourceGroupNameTextBox.Text -ErrorAction SilentlyContinue)
    {
        $CreateRG = [System.Windows.MessageBox]::Show("The Resource Group " + $ResourceGroupNameTextBox.Text + " has been successfully created.`nIf you are finished creating creating resource groups, press Yes to close form and continue or `npress No to create another resource Group.",'Resource Group Creation','YesNo','Question')
    }
    else
    {
        [System.Windows.MessageBox]::Show("The Resource Group " + $ResourceGroupNameTextBox.Text + " failed to create. Press OK to try again.",'Resource Group Creation','Ok','Error')
        $ResourceGroupNameTextBox.Enabled = $true
        $CreateNewRGButton.Enabled = $False
        $VerifyNewRGButton.Enabled = $True
    }

    If($CreateRG -eq "Yes")
    {
        SubscriptionDropDownChange
        $NewRGCheckBox.Checked = $False
        $ResourceGroupNameTextBox.Enabled = $true
        $ResourceGroupNameTextBox.Clear()
        $CreateNewRGButton.Enabled = $False
        $VerifyNewRGButton.Enabled = $True
    }
    Else
    {
        $ResourceGroupNameTextBox.Enabled = $true
        $ResourceGroupNameTextBox.Clear()
        $CreateNewRGButton.Enabled = $False
        $VerifyNewRGButton.Enabled = $True
        $AzureLocationDropDown.SelectedIndex = 0
        SubscriptionDropDownChange
        CreateNewRGObects "Checked"
    }
}

#### Creating New VNet form Objects - From CheckBox Click
Function CreateVNetObects($checkstate)
{
    If($checkstate -eq "Checked")
    {
        $AzureVirtualNetworkDropdown.Enabled = $False
        CreateTextBoxLabel $NewVNetNameLabel (440*$XMultiplier) (100*$yMultiplier) (200*$xMultiplier) (20*$yMultiplier) "Virtual Network Name"
        CreateTextBoxObject $NewVNetNameTextBox (440*$XMultiplier) (125*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier)
        CreateDropDownMenus $NewVNetDropDown (440*$XMultiplier) (185*$yMultiplier) (200*$XMultiplier) (20*$XMultiplier) (300*$XMultiplier) "- Choose VNet Prefix -"
        CreateTextBoxLabel $NewVNetDescriptionLabel (440*$XMultiplier) (160*$yMultiplier) (200*$xMultiplier) (20*$yMultiplier) "Class B VNets are used for Simplicity"
        CreateButton $VerifyNewVNetButton (440*$XMultiplier) (220*$yMultiplier) (200*$XMultiplier) (40*$xMultiplier) "Verify New VNet" "Validate"
        CreateButton $CreateNewVNetButton (440*$XMultiplier) (270*$yMultiplier) (200*$XMultiplier) (40*$xMultiplier) "Create New VNet" "Create"
        CreatePictureBox $InfraStatusWhiteBackground (400*$xMultiplier) (80*$yMultiplier) "Yes" "InfraBackWallPaperWhite.png"
        $InfraStatusWhiteBackground.BringToFront()
        $InfraStatusWhiteBackground.Show()

        $VerifyNewVNetButton.FlatAppearance.BorderSize = 0
        $CreateNewVNetButton.FlatAppearance.BorderSize = 0
        RoundCorners $VerifyNewVNetButton
        RoundCorners $CreateNewVNetButton

        $NewComponentInfraBackground.Multiline = $True
        $NewComponentInfraBackground.BringToFront()
        $NewComponentInfraBackground.ReadOnly = $True
        $NewComponentInfraBackground.BringToFront()
        $NewVNetNameLabel.Show()
        $NewVNetNameLabel.BringToFront()
        $NewVNetNameTextBox.Show()
        $NewVNetNameTextBox.BringToFront()
        $NewVNetDropDown.Show()
        $NewVNetDropDown.BringToFront()
        $NewVNetDescriptionLabel.Show()
        $NewVNetDescriptionLabel.BringToFront()
        $VerifyNewVNetButton.Show()
        $VerifyNewVNetButton.BringToFront()
        $CreateNewVNetButton.Show()
        $CreateNewVNetButton.BringToFront()
        $CreateNewVNetButton.Enabled = $False
        $CreateNewVNetButton.BackColor = "#aba7a7"
        $NewVNetDropDown.enabled = $true
        $NewVNetNameLabel.BackColor = "#ffffff"
        $NewVNetDescriptionLabel.BackColor = "#ffffff"
        ### Retrieving Subnets to be used for duplicate checking when building the dropdown
        $VNetAddressList = (Get-AzVirtualNetwork -ResourceGroupName $Global:ResourceGroupName).AddressSpace.AddressPrefixes
        #### Populatng dropdown menu
        $VNETCreateCheck = 1
        $VNETFirstOctet = 10
        DO
        {
            $VnetString = [string]$VNETFirstOctet + '.0.0.0/16'
            $Match = $false
            ForEach($Address in $VNetAddressList)
            {
                [String]$VNetFromArray = $Address
                If($VnetString -eq $VNetFromArray)
                {
                    $Match = $True
                    $VNETFirstOctet++
                }
            }
            If($Match -eq $false)
            {
                $NewVNetDropDown.Items.Add($VnetString)
                $VNETFirstOctet++
                $VNETCreateCheck++
            }            
        } Until ($VNETCreateCheck -gt 10)
        SortDropDownMenu $NewVNetDropDown
    }
    Else
    {
        $AzureVirtualNetworkDropdown.Enabled = $True
        $NewVNetDropDown.Items.Clear()
        $NewVNetNameLabel.Hide()
        $NewVNetNameTextBox.Hide()
        $NewVNetDropDown.Hide()
        $NewVNetDescriptionLabel.Hide()
        $VerifyNewVNetButton.Hide()
        $CreateNewVNetButton.Hide()
        $InfraStatusWhiteBackground.Hide()
    } 
}

Function VerifyVNet
{
    ### Resetting Items to enabled state
    $NewVNetNameTextBox.Enabled = $true
    $CreateNewVNetButton.Enabled = $False
    $VerifyNewVNetButton.Enabled = $True

    $ValidationPassed = $False
    If($NewVNetNameTextBox.Text -NE "")
    {
        if(Get-AzVirtualNetwork -ResourceGroupName $Global:ResourceGroupName -Name $NewVNetNameTextBox.Text -ErrorAction SilentlyContinue)
        {
            
            [System.Windows.MessageBox]::Show("The VNet " + $NewVNetNameTextBox.Text + " already exists. Press OK to try again.",'Virtual Network Validation','OK','Error')
        }
        else
        {
            ### Checking for special Characters and Spaces
            If(($NewVNetNameTextBox.Text -match '[^a-zA-Z0-9^-]') -eq $True)
            {
                [System.Windows.MessageBox]::Show("The VNet Name cannot contain spaces or special characters.`nPress OK to try again.",'Virtual Network Validation','OK','Error')
            }
            Else
            {
                If($NewVNetDropDown.SelectedIndex -eq 0)
                {
                    $VNetSelectionMsgText = "VNet Address Prefix is not selected, press OK to continue and select a VNet Address Prefix."
                    [System.Windows.MessageBox]::Show($VNetSelectionMsgText,'Virtual Network Validation','OK','Error')
                }
                Else
                {
                    $VNetSelectionMsgText = "Verify that " + $NewVNetDropDown.Text + " is the correct Address Prefix."
                    $ValidationPassed = [System.Windows.MessageBox]::Show($VNetSelectionMsgText + "`nThe Virtual Network " + $ResourceGroupNameTextBox.Text + " has passed Validation. Press Yes to Continue or No to Go Back",'Virtual Network Validation','YesNo','Question')
                }
            }
        }
    }
    Else
    {
        [System.Windows.MessageBox]::Show("The New VNet Group Name Field cannot be left bank. Press OK to try again.",'Virtual Network Validation','OK','Error')
    }
    
    If($ValidationPassed -eq "Yes")
    {
        $VerifyNewVNetButton.Enabled = $False
        $CreateNewVNetButton.Enabled = $true
        $NewVNetNameTextBox.Enabled = $False
        $VerifyNewVNetButton.BackColor = "#aba7a7"
        $CreateNewVNetButton.BackColor = "#7eb801"
    }
    Else
    {
        $NewVNetNameTextBox.Enabled = $true
        $CreateNewVNetButton.Enabled = $False
    }

}

Function CreateNewVNet
{
    [String]$VNetNameText = $NewVNetNameTextBox.Text
    $RGLocation = (Get-AzResourceGroup -Name $Global:ResourceGroupName).Location
    New-AzVirtualNetwork -Name $VNetNameText -ResourceGroupName $Global:ResourceGroupName -Location $RGLocation -AddressPrefix $NewVNetDropDown.Text
    If(Get-AzVirtualNetwork -ResourceGroupName $Global:ResourceGroupName -Name $VNetNameText -ErrorAction SilentlyContinue)
    {
        $CreateVNet = [System.Windows.MessageBox]::Show("The VNet " + $VNetNameText + " has been successfully created.`nIf you are finished creating creating VNets, press Yes to close form and continue or `npress No to create another VNet.",'Virutal Network Creation','YesNo','Question')
    }
    else
    {
        [System.Windows.MessageBox]::Show("The VNet " + $VNetNameText + " failed to create. Press OK to try again.",'Virutal Network Creation','Ok','Error')
        $VerifyNewVNetButton.BackColor = "#aba7a7"
        $CreateNewVNetButton.BackColor = "#7eb801"
        $NewVNetNameTextBox.Enabled = $true
        $CreateNewVNetButton.Enabled = $False
        $VerifyNewVNetButton.Enabled = $True
    }

    If($CreateVNet -eq "Yes")
    {
        ResourceGroupChange
        $NewVnetCheckBox.Checked = $False
        $NewVNetNameTextBox.Enabled = $true
        $NewVNetNameTextBox.Clear()
        $VerifyNewVNetButton.BackColor = "#aba7a7"
        $CreateNewVNetButton.BackColor = "#7eb801"
        $CreateNewVNetButton.Enabled = $False
        $VerifyNewVNetButton.Enabled = $True
    }
    Else
    {
        $NewVNetNameTextBox.Enabled = $true
        $NewVNetNameTextBox.Clear()
        $VerifyNewVNetButton.BackColor = "#aba7a7"
        $CreateNewVNetButton.BackColor = "#7eb801"
        $CreateNewVNetButton.Enabled = $False
        $VerifyNewVNetButton.Enabled = $True
        ResourceGroupChange
        $NewVNetDropDown.Items.Clear()
        CreateVNetObects "Checked"
        $NewVNetDropDown.SelectedItem = 0
    }
}

Function CreateNewSubNetObects($checkstate)
{
    If($checkstate -eq "Checked")
    {
        $AzureVirtualSubnetDropdown.Enabled = $False
        CreateTextBoxLabel $NewSubnetNameLabel (440*$XMultiplier) (100*$yMultiplier) (200*$xMultiplier) (20*$yMultiplier) "Virtual Network Name"
        CreateTextBoxObject $NewSubnetNameTextBox (440*$XMultiplier) (125*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier)
        CreateDropDownMenus $NewSubnetDropDown (440*$XMultiplier) (185*$yMultiplier) (200*$XMultiplier) (20*$XMultiplier) (300*$XMultiplier) "- Choose Subnet IP Range -"
        CreateTextBoxLabel $NewSubnetDescriptionLabel (440*$XMultiplier) (160*$yMultiplier) (225*$xMultiplier) (20*$yMultiplier) "Class C Subnets are used for Simplicity"
        CreatePictureBox $InfraStatusWhiteBackground (400*$xMultiplier) (80*$yMultiplier) "Yes" "InfraBackWallPaperWhite.png"
        $InfraStatusWhiteBackground.BringToFront()
        $InfraStatusWhiteBackground.Show()
        CreateButton $VerifyNewSubnetButton (440*$XMultiplier) (220*$yMultiplier) (200*$XMultiplier) (40*$xMultiplier) "Verify New Subnet" "Validate"
        CreateButton $CreateNewSubnetButton (440*$XMultiplier) (270*$yMultiplier) (200*$XMultiplier) (40*$xMultiplier) "Create New Subnet" "Create"
        $VerifyNewSubnetButton.FlatAppearance.BorderSize = 0
        $CreateNewSubnetButton.FlatAppearance.BorderSize = 0
        RoundCorners $VerifyNewSubnetButton
        RoundCorners $CreateNewSubnetButton

        $NewComponentInfraBackground.Multiline = $True
        $NewComponentInfraBackground.ReadOnly = $True
        $NewComponentInfraBackground.BringToFront()
        $NewSubnetNameLabel.Show()
        $NewSubnetNameTextBox.Show()
        $NewSubnetDropDown.Show()
        $NewSubnetDescriptionLabel.Show()
        $VerifyNewSubnetButton.Show()
        $CreateNewSubnetButton.Show()
        $NewSubnetNameLabel.BringToFront()
        $NewSubnetNameTextBox.BringToFront()
        $NewSubnetDropDown.BringToFront()
        $NewSubnetDescriptionLabel.BringToFront()
        $VerifyNewSubnetButton.BringToFront()
        $CreateNewSubnetButton.BringToFront()
        $NewSubnetNameLabel.BackColor = "#FFFFFF"
        $NewSubnetDescriptionLabel.BackColor = "#FFFFFF"
        $CreateNewSubnetButton.Enabled = $False
        $CreateNewSubnetButton.BackColor = "#aba7a7"
        $NewSubnetDropDown.enabled = $true

        ### Retrieving Subnets to be used for duplicate checking when building the dropdown
        ### We need to create a vnet object so that we can query the subnet address prefixes
        $VNetObj = (Get-AzVirtualNetwork -ResourceGroupName $Global:ResourceGroupName -Name $AzureVirtualNetworkDropdown.SelectedItem)
        [string]$VNetPrefix = $VNetObj.AddressSpace.AddressPrefixes    
        $SubnetAddrList = Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNetObj
        #### Populatng dropdown menu
        $SubNETCreateCheck = 1
        $SubNETFirstOctet = $VNetPrefix.Substring(0,$VNetPrefix.IndexOf("."))  
        $SubNETThirdOctet = 1
        DO
        {
            $SubnetString = [string]$SubNETFirstOctet + '.0.' + $SubNETThirdOctet + '.0/24'
            $Match = $false 
            ForEach($Address in $SubnetAddrList)
            {
                [String]$SubNetFromArray = $Address.AddressPrefix
                If($SubnetString -eq $SubNetFromArray)
                {
                    $Match = $True
                    $SubNETThirdOctet++
                }
            }
            If($Match -eq $false)
            {
                $NewSubnetDropDown.Items.Add($SubnetString)
                $SubNETThirdOctet++
                $SubNETCreateCheck++
            }            
        } Until ($SubNETCreateCheck -gt 10)
        SortDropDownMenu $NewSubnetDropDown
    }
    Else
    {
        $AzureVirtualSubnetDropdown.Enabled = $True
        $NewSubnetDropDown.Items.Clear()
        $NewSubnetNameLabel.Hide()
        $NewSubnetNameTextBox.Hide()
        $NewSubnetDropDown.Hide()
        $NewSubnetDescriptionLabel.Hide()
        $VerifyNewSubnetButton.Hide()
        $CreateNewSubnetButton.Hide()
        $InfraStatusWhiteBackground.hide()
    } 
}

Function VerifyNewSubnet
{
    ### Resetting Items to enabled state
    $NewSubnetNameTextBox.Enabled = $true
    $CreateNewSubnetButton.Enabled = $False
    $VerifyNewSubnetButton.Enabled = $True

    $ValidationPassed = $False
    If($NewSubnetNameTextBox.Text -NE "")
    {
        $VNetObj = (Get-AzVirtualNetwork -ResourceGroupName $Global:ResourceGroupName -Name $AzureVirtualNetworkDropdown.SelectedItem)  
        if(Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNetObj -Name $NewSubnetNameTextBox.Text -ErrorAction SilentlyContinue)
        {
            
            [System.Windows.MessageBox]::Show("The Subnet " + $NewSubnetNameTextBox.Text + " already exists. Press OK to try again.",'Subnet Validation','OK','Error')
        }
        else
        {
            ### Checking for special Characters and Spaces
            If(($NewSubnetNameTextBox.Text -match '[^a-zA-Z0-9^-]') -eq $True)
            {
                [System.Windows.MessageBox]::Show("The Subnet Name cannot contain spaces or special characters.`nPress OK to try again.",'Subnet Validation','OK','Error')
            }
            Else
            {
                If($NewSubnetDropDown.SelectedIndex -eq 0)
                {
                    $SubNetSelectionMsgText = "Subnet Address Range is not selected, press OK to continue and select a Subnet Address Range."
                    [System.Windows.MessageBox]::Show($SubNetSelectionMsgText,'Subnet Validation','OK','Error')
                }
                Else
                {
                    $SubNetSelectionMsgText = "Verify that " + $NewSubnetDropDown.Text + " is the correct Address Range."
                    $ValidationPassed = [System.Windows.MessageBox]::Show($SubNetSelectionMsgText + "`nThe Subnet " + $NewSubnetNameTextBox.Text + " has passed Validation. Press Yes to Continue or No to Go Back",'Subnet Validation','YesNo','Question')
                }
            }
        }
    }
    Else
    {
        [System.Windows.MessageBox]::Show("The Subnet Name Field cannot be left bank. Press OK to try again.",'Subnet Validation','OK','Error')
    }
    
    If($ValidationPassed -eq "Yes")
    {
        $VerifyNewSubnetButton.Enabled = $False
        $CreateNewSubnetButton.Enabled = $true
        $NewSubnetNameTextBox.enabled = $False
        $VerifyNewSubnetButton.BackColor = "#aba7a7"
        $CreateNewSubnetButton.BackColor = "#7eb801"
    }
    Else
    {
        $VerifyNewSubnetButton.Enabled = $true
        $CreateNewSubnetButton.Enabled = $False
    }
}
Function CreateNewSubnet
{
    $VNetObj = (Get-AzVirtualNetwork -ResourceGroupName $Global:ResourceGroupName -Name $AzureVirtualNetworkDropdown.SelectedItem)  
    Add-AzureRmVirtualNetworkSubnetConfig -Name $NewSubnetNameTextBox.Text -AddressPrefix $NewSubnetDropDown.Text -VirtualNetwork $VNetObj
    Set-AzureRmVirtualNetwork -VirtualNetwork $VNetObj
    $VNetObj = (Get-AzVirtualNetwork -ResourceGroupName $Global:ResourceGroupName -Name $AzureVirtualNetworkDropdown.SelectedItem)
    $Global:SubID = (Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNetObj -Name $NewSubnetNameTextBox.Text).Id

    If(Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNetObj -Name $NewSubnetNameTextBox.Text -ErrorAction Continue)
    {
        $CreateSubNet = [System.Windows.MessageBox]::Show("The Subnet " + $NewSubnetNameTextBox.Text + " has been successfully created.`nIf you are finished creating creating Subnets, press Yes to close the form and continue or `npress No to create another Subnet.",'Subnet Creation','YesNo','Question')
    }
    else
    {
        [System.Windows.MessageBox]::Show("The Subnet " + $NewSubnetNameTextBox.Text + " failed to create. Press OK to try again.",'Subnet Creation','Ok','Error')
        $VerifyNewSubnetButton.BackColor = "#aba7a7"
        $CreateNewSubnetButton.BackColor = "#7eb801"
        $NewSubnetNameTextBox.Enabled = $true
        $CreateNewSubnetButton.Enabled = $False
        $VerifyNewSubnetButton.Enabled = $True
    }

    If($CreateSubNet -eq "Yes")
    {
        NetworkGroupChange
        $NewSubNetCheckBox.Checked = $False
        $NewSubnetNameTextBox.Enabled = $true
        $NewSubnetNameTextBox.Clear()
        $VerifyNewSubnetButton.BackColor = "#aba7a7"
        $CreateNewSubnetButton.BackColor = "#7eb801"
        $CreateNewSubnetButton.Enabled = $False
        $VerifyNewSubnetButton.Enabled = $True
    }
    Else
    {
        $NewSubnetNameTextBox.Enabled = $true
        $NewSubnetNameTextBox.Clear()
        $VerifyNewSubnetButton.BackColor = "#aba7a7"
        $CreateNewSubnetButton.BackColor = "#7eb801"
        $CreateNewSubnetButton.Enabled = $False
        $VerifyNewSubnetButton.Enabled = $True
        NetworkGroupChange
        $NewSubnetDropDown.Items.Clear()
        CreateNewSubNetObects "Checked"
        $NewSubnetDropDown.SelectedItem = 0
    }
}

Function SubnetChange
{   
   IF($AzureVirtualSubnetDropdown.SelectedIndex -gt 0)
    {
        $LabMachineTypeDropdown.Enabled = $False
        $Location = (Get-AzResourceGroup -Name $global:ResourceGroupName).Location
        $VNetObj = (Get-AzVirtualNetwork -ResourceGroupName $Global:ResourceGroupName -Name $AzureVirtualNetworkDropdown.SelectedItem)
        $DropDownName = $AzureVirtualSubnetDropdown.SelectedItem
        $SubnetName = $DropDownName.Substring(0,$DropDownName.IndexOf(' (' ))
        $Global:SubID = (Get-AzVirtualNetworkSubnetConfig -VirtualNetwork $VNetObj -Name $SubnetName).Id

        ### Retrieving VM Types from the Azure Data Center specified in the Network Location
        If($Global:CreationLocationRan -eq $False)
        {
            GetAZMachinesTypes $Location
            GetGalleryImages $Location
            $Global:CreationLocationRan  = $True
        }
        $SubnetCheckImage.show()
        $LabMachineTypeDropdown.Enabled = $True
        $LabMachineTypeDropdown.SelectedIndex = 0
    }
    Else
    {
    }
}

### Clears are machine creation when the machine type dropdown is changed
Function HideMachineCreationObjects
{
   $NewDCNameTextBox.text = "";$NewDCNameTextBox.Hide();$NewDCCountTextBox.text = "";$NewDCCountTextBox.Hide();$NewDCCompNameLabel.Hide();$NewDCCountLabel.Hide();$NewDCImageDropDown.Hide();$NewDCImageDropDown.Items.Clear();$NewDCMachineTypeDropDown.Hide();$NewDCMachineTypeDropDown.Items.Clear();$VerifyNewDCButton.Hide();$CreateNewDCButton.hide()
   $NewMSNameTextBox.Text = "";$NewMSNameTextBox.Hide();$NewMSCountTextBox.Text = "";$NewMSCountTextBox.Hide();$NewMSCompNameLabel.Hide();$NewMSCountLabel.Hide();$NewMSImageDropDown.Hide();$NewMSImageDropDown.Items.Clear();$NewMSMachineTypeDropDown.Hide();$NewMSMachineTypeDropDown.Items.Clear();$VerifyNewMSButton.hide();$CreateNewMSButton.Hide()
   $NewWSCompNameLabel.Hide();$NewWSCountLabel.Hide();$NewWSNameTextBox.Hide();$NewWSNameTextBox.Text = "";$NewWSCountTextBox.Text = "";$NewWSCountTextBox.Hide();$NewWSImageDropDown.Hide();$NewWSImageDropDown.Items.Clear();$NewWSMachineTypeDropDown.Hide();$NewWSMachineTypeDropDown.Items.Clear();$VerifyNewWSButton.Hide();$CreateNewWSButton.hide()
}

Function CreateNewDCObects
{
    ### Removing Old Objects
    DeleteVMDetailObjects

    ### Creating Textboxes and Labels
    CreateTextBoxLabel $NewDCCompNameLabel (60*$XMultiplier) (430*$yMultiplier) (200*$xMultiplier) (15*$yMultiplier) "DC Name Prefix"
    CreateTextBoxLabel $NewDCCountLabel (60*$XMultiplier) (480*$yMultiplier) (200*$xMultiplier) (20*$yMultiplier) "Domain Controller Count"
    CreateTextBoxObject $NewDCNameTextBox (60*$XMultiplier) (450*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier)
    CreateTextBoxObject $NewDCCountTextBox (60*$XMultiplier) (500*$yMultiplier) (40*$XMultiplier) (20*$XMultiplier)

    ### Populating Image Dropdown Menu
    CreateDropDownMenus $NewDCImageDropDown(60*$XMultiplier) (530*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier) (300*$XMultiplier) "- Choose Gallery Image -"
    ForEach($Image in $Global:ServerImageArray){$NewDCImageDropDown.Items.Add($Image)}
    SortDropDownMenu $NewDCImageDropDown
            
    ### Populating Machine Type Dropdown
    CreateDropDownMenus $NewDCMachineTypeDropDown(60*$XMultiplier) (560*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier) (300*$XMultiplier) "- Choose Machine Size -"
    $MachineSizeTable= $Global:BClassTable.GetEnumerator()
    ForEach($MachineType in $MachineSizeTable)
    {
        $MachineType.key
        $RAM = ($Global:BClassTable[$MachineType.key].RAM/1024)
        $CPU = $Global:BClassTable[$MachineType.key].CPU
        If($CPU -ge 2 -and $CPU -le 4 -and $RAM -ge 4 -and $RAM -le 16)
         { 
            [String]$DropDownText = $MachineType.key + "(" + $RAM + "GB RAM," + $CPU + " CPUs)"
            $NewDCMachineTypeDropDown.Items.Add($DropDownText)
        }
    }
    SortDropDownMenu $NewDCMachineTypeDropDown
    CreateButton $VerifyNewDCButton (60*$XMultiplier) (590*$yMultiplier) (200*$XMultiplier) (40*$xMultiplier) "Validate DC Config" "Validate"
    CreateButton $CreateNewDCButton (60*$XMultiplier) (640*$yMultiplier) (200*$XMultiplier) (40*$xMultiplier) 'Create New DC(s)' "Create"
    $VerifyNewDCButton.FlatAppearance.BorderSize = 0
    $CreateNewDCButton.FlatAppearance.BorderSize = 0
    RoundCorners $VerifyNewDCButton
    RoundCorners $CreateNewDCButton
    #$CreateNewDCButton.Enabled = $False
    $CreateNewDCButton.BackColor = "#aba7a7"

    ### Bringing Items to Front
    $NewDCImageDropDown.BringToFront();$NewDCCompNameLabel.BringToFront();$NewDCCountLabel.BringToFront();$NewDCNameTextBox.BringToFront();$NewDCCountTextBox.BringToFront();$NewDCMachineTypeDropDown.BringToFront();$VerifyNewDCButton.BringToFront();$CreateNewDCButton.BringToFront()
}

Function CreateNewMSObects
{      
    ### Removing Old Objects
    DeleteVMDetailObjects

    ### Creating Textboxes and Labels
    CreateTextBoxObject $NewMSNameTextBox (60*$XMultiplier) (450*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier)
    CreateTextBoxObject $NewMSCountTextBox (60*$XMultiplier) (500*$yMultiplier) (40*$XMultiplier) (20*$XMultiplier)
    CreateTextBoxLabel $NewMSCompNameLabel (60*$XMultiplier) (430*$yMultiplier) (200*$xMultiplier) (15*$yMultiplier) "Member Server Name Prefix"
    CreateTextBoxLabel $NewMSCountLabel (60*$XMultiplier) (480*$yMultiplier) (200*$xMultiplier) (20*$yMultiplier) "Member Server Count"
            
    ### Populating Image Dropdown Menu
    CreateDropDownMenus $NewMSImageDropDown (60*$XMultiplier) (530*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier) (300*$XMultiplier) "- Choose Gallery Image -"
    ForEach($Image in $Global:ServerImageArray){$NewMSImageDropDown.Items.Add($Image)}
    SortDropDownMenu $NewMSImageDropDown
        
    ### Populating Machine Type Dropdown
    CreateDropDownMenus $NewMSMachineTypeDropDown (60*$XMultiplier) (560*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier) (300*$XMultiplier) "- Choose Machine Size  -"
    $MachineSizeTable= $Global:DClassTable.GetEnumerator()
    ForEach($MachineType in $MachineSizeTable)
    {
        $MachineType.key
        $RAM = ($Global:DClassTable[$MachineType.key].RAM/1024)
        $CPU = $Global:DClassTable[$MachineType.key].CPU
        If($CPU -ge 4 -and $CPU -le 8 -and $RAM -ge 8 -and $RAM -le 32 -and $MachineType.key -like "Standard_D*V5")
        { 
            [String]$DropDownText = $MachineType.key + "(" + $RAM + "GB RAM," + $CPU + " CPUs)"
            $NewMSMachineTypeDropDown.Items.Add($DropDownText)
        }
    }
    SortDropDownMenu $NewMSMachineTypeDropDown
    CreateButton $VerifyNewMSButton (60*$XMultiplier) (590*$yMultiplier) (220*$XMultiplier) (40*$xMultiplier) "Validate MemberServer Config" "Validate"
    CreateButton $CreateNewMSButton (60*$XMultiplier) (640*$yMultiplier) (220*$XMultiplier) (40*$xMultiplier) 'Create New MemberServer(s)' "Create"
    $VerifyNewMSButton.FlatAppearance.BorderSize = 0
    $CreateNewMSButton.FlatAppearance.BorderSize = 0
    RoundCorners $VerifyNewMSButton
    RoundCorners $CreateNewMSButton
    $CreateNewMSButton.Enabled = $True
    $CreateNewMSButton.BackColor = "#aba7a7"

    ### Bringing Items to Front
    $NewMSImageDropDown.BringToFront();$NewMSCompNameLabel.BringToFront();$NewMSCountLabel.BringToFront();$NewMSNameTextBox.BringToFront();$NewMSCountTextBox.BringToFront();$NewMSMachineTypeDropDown.BringToFront();$VerifyNewMSButton.BringToFront();$CreateNewMSButton.BringToFront()
}

Function CreateNewWSObects
{
    ### Removing Old Objects
    DeleteVMDetailObjects

    ### Creating Textboxes and Labels
    CreateTextBoxLabel $NewWSCompNameLabel (60*$XMultiplier) (430*$yMultiplier) (200*$xMultiplier) (15*$yMultiplier) "Workstation Name Prefix"
    CreateTextBoxLabel $NewWSCountLabel (60*$XMultiplier) (480*$yMultiplier) (200*$xMultiplier) (20*$yMultiplier) "Workstation Count"
    CreateTextBoxObject $NewWSNameTextBox (60*$XMultiplier) (450*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier)
    CreateTextBoxObject $NewWSCountTextBox (60*$XMultiplier) (500*$yMultiplier) (40*$XMultiplier) (20*$XMultiplier)

    ### Populating Image Dropdown Menu
    CreateDropDownMenus $NewWSImageDropDown (60*$XMultiplier) (530*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier) (300*$XMultiplier) "- Choose Gallery Image -"
    ForEach($Image in $Global:DesktopImageArray){$NewWSImageDropDown.Items.Add($Image)}
    SortDropDownMenu $NewWSImageDropDown
       
    ### Populating Machine Type Dropdown
    CreateDropDownMenus $NewWSMachineTypeDropDown (60*$XMultiplier) (560*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier) (300*$XMultiplier) "- Choose Machine Size  -"
    $MachineSizeTable= $Global:DClassTable.GetEnumerator()
    ForEach($MachineType in $MachineSizeTable)
    {
        $MachineType.key
        $RAM = ($Global:DClassTable[$MachineType.key].RAM/1024)
        $CPU = $Global:DClassTable[$MachineType.key].CPU
        If($CPU -ge 2 -and $CPU -le 4 -and $RAM -ge 2 -and $RAM -le 16 -and $MachineType.key -like "Standard_DS*V2")
        { 
            [String]$DropDownText = $MachineType.key + "(" + $RAM + "GB RAM," + $CPU + " CPUs)"
            $NewWSMachineTypeDropDown.Items.Add($DropDownText)
        }
    }
    SortDropDownMenu $NewWSMachineTypeDropDown
    CreateButton $VerifyNewWSButton (60*$XMultiplier) (590*$yMultiplier) (220*$XMultiplier) (40*$xMultiplier) 'Validate Workstation Config' "Validate"
    CreateButton $CreateNewWSButton (60*$XMultiplier) (640*$yMultiplier) (220*$XMultiplier) (40*$xMultiplier) 'Create New Workstation(s)' "Create"
    $VerifyNewWSButton.FlatAppearance.BorderSize = 0
    $CreateNewWSButton.FlatAppearance.BorderSize = 0
    RoundCorners $VerifyNewWSButton
    RoundCorners $CreateNewWSButton

    ### Checking to see if JumpBox has been selected to change the display value labels and buttons
    If($LabMachineTypeDropdown.SelectedItem -eq "JumpBox")
    {
        $VerifyNewWSButton.Text = 'Validate JumpBox Config';$CreateNewWSButton.Text = 'Create New JumpBox(es)';$NewWSCompNameLabel.text = "JumpBox Name Prefix";$NewWSCountLabel.text = "JumpBox Count"
    }
    $CreateNewWSButton.Enabled = $False
    $CreateNewWSButton.BackColor = "#aba7a7"

    ### Bringing Items to Front
    $NewWSImageDropDown.BringToFront();$NewWSCompNameLabel.BringToFront();$NewWSCountLabel.BringToFront();$NewWSNameTextBox.BringToFront();$NewWSCountTextBox.BringToFront();$NewWSMachineTypeDropDown.BringToFront();$VerifyNewWSButton.BringToFront();$CreateNewWSButton.BringToFront()
}

Function DeleteVMDetailObjects
{
    ### Deleting Old Computer Buttons and Labels
    If($Global:VMPrefix -ne $null)
    {
        $Global:VMMachineCountLabel.hide()
        $Column3ProgressBar.hide()
        $CompButtonArray = (Get-Variable -Include "$Global:VMPrefix*").Name
        ForEach($Object in $CompButtonArray)
        {
            #Write-Host $Object
            $Global:form.Controls.Removebykey($Object)
            Remove-Variable -Name $Object -Scope Global
        }
        (Get-Variable -Include "$Global:VMPrefix*").Name
    }
} 

Function VerifyVMConfiguration($ImageDropdown,$MachineTypeDrodown,$NamePrefix,$Count,$VerifyButton,$CreateButton)
{
 ### Resetting Items to enabled state
    $NamePrefix.Enabled = $true
    $CreateButton.Enabled = $False
    $VerifyButton.Enabled = $True

    $ValidationPassed = $False
    If($NamePrefix.text -NE "")
    {
        ### Checking for special Characters and Spaces (Even though this likes the opposite)
        If(($NamePrefix.text -match '[^a-zA-Z0-9^-]') -eq $True)
        {
            [System.Windows.MessageBox]::Show("The VM Name Prefix cannot contain spaces or special characters.`nPress OK to try again.",'VM Validation','OK','Error')
        }
        Else
        {
            If($NamePrefix.text.Length -ge 10)
            {
                [System.Windows.MessageBox]::Show("The VM Name Prefix cannot exceed 9 characters.`nPress OK to try again.",'VM Validation','OK','Error')
            }
            Else
            {
                If($Count.text -ge 10 -and $count.text -lt 1 -or $Count.text -eq "")
                {
                    [System.Windows.MessageBox]::Show("The VM Count cannot exceed 9 devices or it has been left blank.`nPress OK to try again.",'VM Validation','OK','Error')
                }
                Else
                {
                    If($ImageDropdown.SelectedIndex -eq 0)
                    {
                        $ImageSelectionMsgText = "Machine Image Type is not selected, press OK to continue and select a Machine Image Type."
                        [System.Windows.MessageBox]::Show($ImageSelectionMsgText,'VM Validation','OK','Error')
                    }
                    Else
                    {
                        If($MachineTypeDrodown.SelectedIndex -eq 0)
                        {
                            $MachineTypeMsgText = "Azure Machine Size is not selected, press OK to continue and select an Azure Machine Size."
                            [System.Windows.MessageBox]::Show($MachineTypeMsgText,'VM Validation','OK','Error')
                        }
                        Else
                        {                
                            $VMSelectionMsgText = "Verify that " + $NamePrefix.Text + ", " + $ImageDropdown.selectedItem + ", " + $MachineTypeDrodown.selectedItem + " match the desired VM confiuration"
                            $ValidationPassed = [System.Windows.MessageBox]::Show("VM Configuration has passed Validation. " + $VMSelectionMsgText + " Press Yes to Continue or No to Go Back",'VM Validation','YesNo','Question')
                        }
                    }
                }
            }
        }
    }
    Else
    {
        [System.Windows.MessageBox]::Show("The VM Name Prefix cannot be left bank. Press OK to try again.",'VM Validation','OK','Error')
    }
    
    If($ValidationPassed -eq "Yes")
    {
        $VerifyButton.Enabled = $False
        $CreateButton.Enabled = $true
        $NamePrefix.enabled = $False
        $ImageDropdown.enabled = $False
        $MachineTypeDrodown.enabled = $False
        $Count.enabled = $False
        $VerifyButton.BackColor = "#aba7a7"
        $CreateButton.BackColor = "#7eb801"
    }
    Else
    {
        $VerifyButton.Enabled = $true
        $CreateButton.Enabled = $False
    }
}

Function CreateVM($ImageDropdown,$MachineTypeDrodown,$NamePrefix,$Count,$progbar,$CreateButton,$VerifyButton,$CountTextBox,$PrefixTextBox)
{
    ### Removing Old Objects
    DeleteVMDetailObjects

    $MachineCount = 0
    $Global:VMMachineCountLabel = New-Object System.Windows.Forms.Label
    $Global:VMMachineCountLabel.Location = New-Object System.Drawing.Point((425*$XMultiplier),(425*$yMultiplier))
    $Global:VMMachineCountLabel.Size = New-Object System.Drawing.Size(250,10)
    $Global:VMMachineCountLabel.Text = "Creating Machine $MachineCount out of $Count"
    $Global:VMMachineCountLabel.Font = New-Object System.Drawing.Font("Calibri",9,[System.Drawing.FontStyle]::Regular)
    $Global:VMMachineCountLabel.Show()
    $Global:VMMachineCountLabel.BackColor = "#ffffff"
    $Global:VMMachineCountLabel.TextAlign = [System.Drawing.ContentAlignment]::MIddleCenter
    $Global:form.Controls.Add($Global:VMMachineCountLabel)
    $Global:VMMachineCountLabel.BringToFront()

    ### This Table will store the VMDetail URLs 
    $Global:VMAttributeMapping = @{}

    ProgBar $progbar (425*$XMultiplier) (445*$yMultiplier) (250*$XMultiplier) (15*$yMultiplier)
    DO
    {
        
        $MachineCount++
        $Global:VMMachineCountLabel.Text = "Creating Machine $MachineCount out of $Count"
        $progbar.value = 0
        $VMLocalAdminUser = $LocalAdminName
        $progbar.bringtoFront()
        $VMLocalAdminSecurePassword = ConvertTo-SecureString $LocalPassword -AsPlainText -Force
        $LocationName = (Get-AzResourceGroup -Name $global:ResourceGroupName).Location
        $ResourceGroupName = $global:ResourceGroupName
        $NameSuffix = Get-Random -Minimum 1000 -Maximum 9999
        [string]$ComputerName = $NamePrefix + "-" + $NameSuffix
        $VMName = $ComputerName

        ### Adding Dynamic Button Objects

        ### Writing Logic for X and Y Coordinates
        ### X Coordinates
        If($MachineCount -eq 1 -or $MachineCount -eq 4 -or $MachineCount -eq 7){$XCoord=(425*$XMultiplier)}
        If($MachineCount -eq 2 -or $MachineCount -eq 5 -or $MachineCount -eq 8){$XCoord=(505*$XMultiplier)}
        If($MachineCount -eq 3 -or $MachineCount -eq 6 -or $MachineCount -eq 9){$XCoord=(585*$XMultiplier)}

        ### Y Coordinates
        If($MachineCount -eq 1 -or $MachineCount -eq 2 -or $MachineCount -eq 3){$yCoord=(470*$yMultiplier)}
        If($MachineCount -eq 4 -or $MachineCount -eq 5 -or $MachineCount -eq 6){$yCoord=(545*$yMultiplier)}
        If($MachineCount -eq 7 -or $MachineCount -eq 8 -or $MachineCount -eq 9){$yCoord=(620*$yMultiplier)}
        
        $ButtonNameString = $VMName + "Button"
        $LabelNameString = $VMName + "Label" 
        New-Variable -Name $ButtonNameString -Scope global
        New-Variable -Name $LabelNameString -Scope global 
        $ButtonVar = (Get-Variable -Name $ButtonNameString).Name
        $ButtonVar = New-Object System.Windows.Forms.Button
        $LabelVar = (Get-Variable -Name $LabelNameString).Name
        $LabelVar = New-Object System.Windows.Forms.Label

        $ButtonVar.Location = New-Object System.Drawing.Size(($XCoord+10),$yCoord) 
        $ButtonVar.Size = New-Object System.Drawing.Size(($Global:VMButtonImage.width*$XMultiplier),($Global:VMButtonImage.height*$xMultiplier)) 
        $ButtonVar.Name=$ButtonNameString
        $ButtonVar.FlatAppearance.BorderSize = 0
        $ButtonVar.BackgroundImage = $Global:VMButtonImage
        $ButtonVar.BringToFront()
        $ButtonVar.add_click([scriptblock]::Create("VMMachineDetail $VMName")) 
        $Global:form.controls.add($ButtonVar)
        $ButtonVar.BringToFront()

        $LabelVar.Location = New-Object System.Drawing.Point($XCoord,($yCoord+40))
        $LabelVar.Size = New-Object System.Drawing.Size(100,10)
        $LabelVar.Name = $LabelNameString
        $LabelVar.Text = $VMName
        $LabelVar.Font = New-Object System.Drawing.Font("Calibri",8,[System.Drawing.FontStyle]::Regular)
        $LabelVar.Show()
        $LabelVar.BackColor = "#ffffff"
        $Global:form.Controls.Add($LabelVar)
        $LabelVar.BringToFront()
#<#
        $DataDiskName = $ComputerName + "-DataDisk"
        [int]$diskSizeInGB = [convert]::ToInt32(128, 10)
        $MachineTypefromDropDown = $MachineTypeDrodown.selectedItem 
        $VMSize = $MachineTypefromDropDown.Substring(0,$MachineTypefromDropDown.IndexOf('(' ))
        $OSString = $ImageDropdown.selectedItem
        If($OSString -like "*-ent*" -and $OSString  -like "Win10*"){$Publisher,$Offer="MicrosoftWindowsDesktop","Windows-10"}
        If($OSString -like "*-ent*" -and $OSString  -like "Win11*"){$Publisher,$Offer="MicrosoftWindowsDesktop","Windows-11"}
        If($OSString -like "*-Datacenter*"){$Publisher,$Offer="MicrosoftWindowsserver","WindowsServer"}
        $NICName = "NIC-" + $ComputerName
        $NIC = New-AzNetworkInterface -Name $NICName -ResourceGroupName $ResourceGroupName -Location $LocationName -SubnetId $Global:SubID
        
        #write-host $NICURL
        $progbar.value = 10
        $Credential = New-Object System.Management.Automation.PSCredential ($VMLocalAdminUser, $VMLocalAdminSecurePassword)
        $VirtualMachine = New-AzVMConfig -VMName $VMName -VMSize $VMSize
        $progbar.value = 20
        $VirtualMachine = Set-AzVMOperatingSystem -VM $VirtualMachine -Windows -ComputerName $ComputerName -Credential $Credential -ProvisionVMAgent -EnableAutoUpdate
        $progbar.value = 30
        $VirtualMachine = Add-AzVMNetworkInterface -VM $VirtualMachine -Id $NIC.Id -DeleteOption Delete
        $progbar.value = 40
        $VirtualMachine = Set-AzVMOSDisk -StorageAccountType StandardSSD_LRS -VM $VirtualMachine -CreateOption fromImage -DeleteOption Delete
        $progbar.value = 50

        ### If Device Type is member server - Add in a data disk
        If($MachineTypeDrodown -eq $NewMSMachineTypeDropDown){$VirtualMachine = Add-AzVMDataDisk -VM $VirtualMachine -Name $DataDiskName  -DiskSizeInGB $diskSizeInGB -CreateOption Empty -StorageAccountType StandardSSD_LRS -Lun 1 -DeleteOption Delete}
        $VirtualMachine = Set-AzVMSourceImage -VM $VirtualMachine -PublisherName $Publisher -Offer $Offer -Skus $ImageDropdown.selectedItem -Version latest -Verbose
        New-AzVM -ResourceGroupName $ResourceGroupName -Location $LocationName -VM $VirtualMachine -Verbose
                #>#
        ### Setting Attribute URLS for the VM Detail Pane
        $CompName = $VMName
        $VMID = (Get-AzVM -Name $VMName).Id
        [string]$VMURL =  "https://portal.azure.com/#@" + $TenantName + "/resource" + $VMID  + "/overview"
        $RGID = (Get-AzResourceGroup -Name $ResourceGroupName).ResourceId
        [String]$RGURL = "https://portal.azure.com/#@" + $TenantName + "/resource" + $RGID + "/overview"
        #$NICID = (Get-AzNetworkInterface -Name $NICName).Id If you want to get a more detailed drill down to the NIC build the string using the NICID - "https://portal.azure.com/#@" + $TenantName + "/resource" + $NICID + "/overview"
        [String]$NICURL = "https://portal.azure.com/#@" + $TenantName + "/resource" + $VMID  + "/Networking"
        $VNETID = (Get-AzVirtualNetwork -Name $AzureVirtualNetworkDropdown.SelectedItem).Id
        [string]$VNETURL = "https://portal.azure.com/#@" + $TenantName + "/resource" + $VNETID + "/overview"      
        [string]$StorageURL = "https://portal.azure.com/#@" + $TenantName + "/resource" + $VMID  + "/Disks"
        $Global:VMAttributeMapping+= @{$CompName = [PSCustomObject]@{VMUrl=$VMURL;NICUrl=$NICURL;StorageURL=$StorageURL;RGURL=$RGURL;VNETURL=$VNETURL}}
        $progbar.value = 100
    }Until($MachineCount -ge $Count)

    ### Resetting / Enabling buton and field states
    $ImageDropdown.enabled = $True
    $MachineTypeDrodown.enabled = $True
    $VerifyButton.BackColor = "#7eb801"
    $CreateButton.BackColor = "#aba7a7"
    $VerifyButton.Enabled = $true
    $CreateButton.Enabled = $False
    $CountTextBox.enabled = $True
    $PrefixTextBox.enabled = $True
    $CountTextBox.text = ""
    $PrefixTextBox.text = ""
    ### VMPrefix is set so that if you change the dropdown to select a different type of machine (DC / WKS / etc..) that it can clear the existing buttons and labels
    $Global:VMPrefix = $NamePrefix
}


Function ProgBar($ProgressBar,$PosX,$PosY,$BoxLen,$Boxheight,$Color)
{
    $ProgressBar.Location = New-Object System.Drawing.Point($PosX, $PosY)
    $ProgressBar.Size = New-Object System.Drawing.Size($BoxLen, $Boxheight)
    $ProgressBar.Style = "Continuous"
    $Global:Form.Controls.Add($ProgressBar)
    $ProgressBar.visible
    $ProgressBar.show()
}

Function VMMachineDetail($MachineName)
{
    $VMAttributeTable= $Global:VMAttributeMapping.GetEnumerator()
    ForEach($VM in $VMAttributeTable)
    {
        If($VM.Key -eq $MachineName)
        {
            [string]$VMLink = $Global:VMAttributeMapping[$VM.key].VMUrl
            [string]$NICLink = $Global:VMAttributeMapping[$VM.key].NICUrl
            [string]$RGLink = $Global:VMAttributeMapping[$VM.key].RGURl
            [string]$StorageLink = $Global:VMAttributeMapping[$VM.key].StorageURL
            [string]$VNETLink = $Global:VMAttributeMapping[$VM.key].VNETURL

            $VMDetailButton.Add_Click({Start-Process -FilePath "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList "$VMLink"})
            $NICDetailButton.Add_Click({Start-Process -FilePath "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList "$NICLink"})
            $RGDetailButton.Add_Click({Start-Process -FilePath "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList "$RGLink"})
            $VHDDetailButton.Add_Click({Start-Process -FilePath "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList "$StorageLink"})
            $VNETDetailButton.Add_Click({Start-Process -FilePath "C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" -ArgumentList "$VNETLink"})
            #(Write-Host $Global:VMAttributeMapping[$VM.key].VMUrl)
        }
    }
    $Global:MachineDetailForm.Text = "$MachineName Detail Pane" 
    $Global:MachineDetailForm.ShowDialog()
}

Function RoundCorners($Object)
{    
$code = @"
  [System.Runtime.InteropServices.DllImport("gdi32.dll")]
  public static extern IntPtr CreateRoundRectRgn(int nLeftRect,int nTopRect,
  int nRightRect,int nBottomRect, int nWidthEllipse, int nHeightEllipse);
"@
    $Win32Helpers = Add-Type -MemberDefinition $code -Name "Win32Helpers" -PassThru
    $ObjectRegion = $Win32Helpers::CreateRoundRectRgn(0,0,$Object.Width,$Object.Height,20,20)
    $Object.Region = [Region]::FromHrgn($ObjectRegion)
}

#### Creating Form Objects
### Setting Variable for Location and VM Size Dropdown Menu
$Global:CreationLocationRan = $False
### Creating Background Form Objects

### Creating Dropdown Menus
CreateDropDownMenus $AzureSubscriptionsDropdown (60*$XMultiplier) (80*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier) (300*$XMultiplier) "- Choose Azure Subscription -"
CreateDropDownMenus $AzureResourceGroupDropdown (60*$XMultiplier) (140*$yMultiplier) (300*$XMultiplier) (20*$XMultiplier) (300*$XMultiplier) "- Choose Azure Resource Group -"
CreateDropDownMenus $AzureVirtualNetworkDropdown (60*$XMultiplier) (210*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier) (300*$XMultiplier) "- Choose Azure VNet -"
CreateDropDownMenus $AzureVirtualSubnetDropdown (60*$XMultiplier) (280*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier) (300*$XMultiplier) "- Choose Azure Subnet -"
CreateDropDownMenus $LabMachineTypeDropdown (60*$XMultiplier) (400*$yMultiplier) (250*$XMultiplier) (20*$XMultiplier) (300*$XMultiplier) "- Choose Machine Type -"
$LabMachineTypeDropdown.Items.Add("Domain Controller")
$LabMachineTypeDropdown.Items.Add("Member Server")
$LabMachineTypeDropdown.Items.Add("Workstation")
$LabMachineTypeDropdown.Items.Add("JumpBox")
$LabMachineTypeDropdown.Enabled = $False
### Creating Text Labels
CreateTextBoxLabel $NewRGLabel (80*$XMultiplier) (112.5*$yMultiplier) (150*$xMultiplier) (15*$yMultiplier) "Create New Resource Group"
CreateTextBoxLabel $NewVNetLabel (80*$XMultiplier) (182.5*$yMultiplier) (200*$xMultiplier) (15*$yMultiplier) "Create New Vnet"
CreateTextBoxLabel $NewSubnetLabel (80*$XMultiplier) (252.5*$yMultiplier) (200*$xMultiplier) (15*$yMultiplier) "Create New Subnet"

### Creating Text Boxes



### Creating Buttons
$MinImage = [System.Drawing.Image]::Fromfile("$CurrentDirectory\Minimize.png")
$MinHoverImage = [System.Drawing.Image]::Fromfile("$CurrentDirectory\MinimizeDark.png")
$ExitImage = [System.Drawing.Image]::Fromfile("$CurrentDirectory\CloseWhite.png")
$ExitHoverImage = [System.Drawing.Image]::Fromfile("$CurrentDirectory\Close.png")
CreateButton $MinButton (722*$XMultiplier) (0*$yMultiplier) ($MinImage.Width*$XMultiplier) ($MinImage.Height*$xMultiplier) ""
CreateButton $ExitButton (761*$XMultiplier) (0*$yMultiplier) ($ExitImage.Width*$XMultiplier) ($ExitImage.height*$xMultiplier) ""
$MinButton.BackgroundImage = $MinImage ; $MinButton.BackColor = "#e4dede" ; $MinButton.FlatAppearance.BorderSize = 0
$ExitButton.BackgroundImage = $ExitImage ; $ExitButton.BackColor = "#e4dede" ; $ExitButton.FlatAppearance.BorderSize = 0

### Creating CheckBox
CreateCheckBox $NewRGCheckBox (60*$XMultiplier) (110*$yMultiplier)
$NewRGCheckBox.Enabled = $false
$NewRGCheckBox.BringToFront()
CreateCheckBox $NewVnetCheckBox (60*$XMultiplier) (180*$yMultiplier)
$NewVnetCheckBox.Enabled = $false
CreateCheckBox $NewSubNetCheckBox (60*$XMultiplier) (250*$yMultiplier)
$NewSubNetCheckBox.Enabled = $false

### Populating Azure Subscriptions
$AzureSubscriptionsDropdown.Enabled = $true
$AzureSubscriptions = get-azsubscription | select name
ForEach($Subscription in $AzureSubscriptions){$AzureSubscriptionsDropdown.Items.Add($Subscription.Name)}
$AzureSubscriptionsDropdown.Sorted = $true
$AzureSubscriptionsDropdown.SelectedItem = $AzureSubscriptionsDropdown.Items[0]

### Populating AZ Locations Table
GetAZLocations
#CreateNewRGObects

### Dropdown Change Actions
$AzureSubscriptionsDropdown.Add_SelectedValueChanged({SubscriptionDropDownChange})
$AzureResourceGroupDropdown.Add_SelectedValueChanged({ResourceGroupChange})
$AzureVirtualNetworkDropdown.Add_SelectedValueChanged({NetworkGroupChange})
$AzureVirtualSubnetDropdown.Add_SelectedValueChanged({SubnetChange})
$LabMachineTypeDropdown.Add_SelectedValueChanged(
    {
        If($LabMachineTypeDropdown.SelectedItem -eq "Domain Controller"){HideMachineCreationObjects;CreateNewDCObects}
        If($LabMachineTypeDropdown.SelectedItem -eq "Member Server"){HideMachineCreationObjects;CreateNewMSObects}
        If($LabMachineTypeDropdown.SelectedItem -eq "Workstation" -or $LabMachineTypeDropdown.SelectedItem -eq "JumpBox" ){HideMachineCreationObjects;CreateNewWSObects}
    }
)

### CheckBox State Change Actions
$NewVnetCheckBox.Add_CheckStateChanged({CreateVNetObects $NewVnetCheckBox.CheckState})
$NewRGCheckBox.Add_CheckStateChanged({CreateNewRGObects $NewRGCheckBox.CheckState})
$NewSubNetCheckBox.Add_CheckStateChanged({CreateNewSubNetObects $NewSubNetCheckBox.CheckState}) 
$NewDCCheckBox.Add_CheckStateChanged({CreateNewDCObects $NewDCCheckBox.CheckState})
$NewMSCheckBox.Add_CheckStateChanged({CreateNewMSObects $NewMSCheckBox.CheckState})
$NewWSCheckBox.Add_CheckStateChanged({CreateNewWSObects $NewWSCheckBox.CheckState})

### Button Click Actions
$VerifyNewRGButton.Add_Click({VerifyRG})
$CreateNewRGButton.Add_Click({CreateNewRG})
$VerifyNewVNetButton.Add_Click({VerifyVNet})
$CreateNewVNetButton.Add_Click({CreateNewVNet})
$VerifyNewSubnetButton.Add_Click({VerifyNewSubnet})
$CreateNewSubnetButton.Add_Click({CreateNewSubnet})
$CreateNewDCButton.Add_Click({CreateVM $NewDCImageDropDown $NewDCMachineTypeDropDown $NewDCNameTextBox.text $NewDCCountTextBox.Text $Column3ProgressBar $CreateNewDCButton $VerifyNewDCButton $NewDCCountTextBox $NewDCNameTextBox})
$CreateNewMSButton.Add_Click({CreateVM $NewMSImageDropDown $NewMSMachineTypeDropDown $NewMSNameTextBox.text $NewMSCountTextBox.Text $Column3ProgressBar $CreateNewMSButton $VerifyNewMSButton $NewMSCountTextBox $NewMSNameTextBox})
$CreateNewWSButton.Add_Click({CreateVM $NewWSImageDropDown $NewWSMachineTypeDropDown $NewWSNameTextBox.text $NewWSCountTextBox.Text $Column3ProgressBar $CreateNewWSButton $VerifyNewWSButton $NewWSCountTextBox $NewWSNameTextBox})
$VerifyNewWSButton.Add_Click({VerifyVMConfiguration $NewWSImageDropDown $NewWSMachineTypeDropDown $NewWSNameTextBox $NewWSCountTextBox $VerifyNewWSButton $CreateNewWSButton})
$VerifyNewMSButton.Add_Click({VerifyVMConfiguration $NewMSImageDropDown $NewMSMachineTypeDropDown $NewMSNameTextBox $NewMSCountTextBox $VerifyNewMSButton $CreateNewMSButton})
$VerifyNewDCButton.Add_Click({VerifyVMConfiguration $NewDCImageDropDown $NewDCMachineTypeDropDown $NewDCNameTextBox $NewDCCountTextBox $VerifyNewDCButton $CreateNewDCButton})
$ExitButton.Add_MouseEnter({$ExitButton.BackgroundImage = $ExitHoverImage ; $ExitButton.BackColor = "#dc1616"})
$ExitButton.Add_MouseLeave({$ExitButton.BackgroundImage = $ExitImage ; $ExitButton.BackColor = "#e4dede"})
$MinButton.Add_MouseEnter({$MinButton.BackgroundImage = $MinHoverImage ; $MinButton.BackColor = "#4c4a48"})
$MinButton.Add_MouseLeave({$MinButton.BackgroundImage = $MinImage ; $MinButton.BackColor = "#e4dede"})
$MinButton.Add_Click({$Global:Form.WindowState = "Minimized"})
$ExitButton.Add_Click({$Global:Form.Close()})

### Creating Items for VM Detail Window
$Global:MachineDetailForm = New-Object System.Windows.Forms.Form    
$Global:MachineDetailForm.Size = New-Object System.Drawing.Size((465*$Global:XMultiplier),(150*$Global:yMultiplier))
$Global:MachineDetailForm.BackColor = "#ffffff"
$Global:MachineDetailForm.Icon = $TitleICO

### Creating Image Objects
$NICImage = [System.Drawing.Image]::Fromfile("$CurrentDirectory\NIC.png")
$ResourceGroupImage = [System.Drawing.Image]::Fromfile("$CurrentDirectory\ResourceGroup.png")
$HDImage = [System.Drawing.Image]::Fromfile("$CurrentDirectory\VHD.png")
$VNet = [System.Drawing.Image]::Fromfile("$CurrentDirectory\VNet.png")
$Global:VMButtonImage = [System.Drawing.Image]::Fromfile("$CurrentDirectory\AzureVM_Pic.png")
$VMDetailImage = [System.Drawing.Image]::Fromfile("$CurrentDirectory\AzureVM_Detail.png")

### Creating Buttons
$VMDetailButton = New-Object System.Windows.Forms.Button
$NICDetailButton = New-Object System.Windows.Forms.Button
$RGDetailButton = New-Object System.Windows.Forms.Button
$VHDDetailButton = New-Object System.Windows.Forms.Button
$VNETDetailButton = New-Object System.Windows.Forms.Button
CreateVMDisplayButton $VMDetailButton (20*$XMultiplier) (20*$yMultiplier) ($VMDetailImage.Width*$XMultiplier) ($VMDetailImage.Height*$yMultiplier) $VMDetailImage
CreateVMDisplayButton $NICDetailButton (105*$XMultiplier) (20*$yMultiplier) ($NICImage.Width*$XMultiplier) ($NICImage.Height*$yMultiplier) $NICImage
CreateVMDisplayButton $RGDetailButton (180*$XMultiplier) (20*$yMultiplier) ($VMDetailImage.Width*$XMultiplier) ($VMDetailImage.Height*$yMultiplier) $ResourceGroupImage
CreateVMDisplayButton $VHDDetailButton (255*$XMultiplier) (20*$yMultiplier) ($HDImage.Width*$XMultiplier) ($HDImage.Height*$yMultiplier) $HDImage
CreateVMDisplayButton $VNETDetailButton (330*$XMultiplier) (20*$yMultiplier) ($VNet.Width*$XMultiplier) ($VNet.Height*$yMultiplier) $VNet

### Activating Form - Form Will get displayed when VM Detail button is pressed
$Global:MachineDetailForm.Add_Shown({$Global:MachineDetailForm.Activate()})


### Presenting Windows Form
$Global:Form.add_Load({RoundCorners $Global:Form})

$Global:Form.Add_Shown({$Global:Form.Activate()})

CreatePictureBox $InfraBackground (40*$xMultiplier) (60*$yMultiplier) "Yes" "InfraBackWallPaper.png"
$InfraBackground.SendToBack()

CreatePictureBox $MachineCreationBackground (40*$xMultiplier) (380*$yMultiplier) "Yes" "MachineCreationBackWallPaper.png"
$MachineCreationBackground.SendToBack()

CreatePictureBox $MachineCreationStatusWhiteBackground (400*$xMultiplier) (400*$yMultiplier) "Yes" "MachineCreateStatusBack_White.png"
$MachineCreationStatusWhiteBackground.BringToFront()

CreatePictureBox $ResourceGroupCheckImage (370*$xMultiplier) (140*$yMultiplier) "No" "CheckBox.png"
$ResourceGroupCheckImage.BringToFront()
$ResourceGroupCheckImage.Hide()
CreatePictureBox $VNetCheckImage (320*$xMultiplier) (210*$yMultiplier) "No" "CheckBox.png"
$VNetCheckImage.BringToFront()
$VNetCheckImage.Hide()
CreatePictureBox $SubnetCheckImage (320*$xMultiplier) (280*$yMultiplier) "No" "CheckBox.png"
$SubnetCheckImage.BringToFront()
$SubnetCheckImage.Hide()

CreateTextBoxObject $MachineCreationStatusTextBox (420*$XMultiplier) (420*$yMultiplier) (260*$yMultiplier) (260*$XMultiplier)
$MachineCreationStatusTextBox.Multiline = $true
$MachineCreationStatusTextBox.BorderStyle = "None"
$MachineCreationStatusTextBox.BringToFront()



$Global:Form.ShowInTaskbar = "True"
[void] $Global:Form.ShowDialog()



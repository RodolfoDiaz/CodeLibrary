# In StrictMode PowerShell generates a terminating error when the content of 
# an expression or script-block violates basic best-practice coding rules.
Set-StrictMode -Version latest
# Exit immediately if a command exits with a non-zero status.
$ErrorActionPreference = "Stop"

# Azure Event Hubs - https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-quickstart-powershell

# Azure Event Hubs works in a Publisher - Subscriber model. In this case, your solution produce series of  time-ordered events, that report
# a condition and enable subscribers to analyze them. For example, telemetry in sensors or in mobile devices: an IoT device, such as temperature sensor
# that keeps sending thousands of messages about the temperature of an industrial equipment over time for analysis by another system.
# Other scenarios include data archival (sending tons of data and have an aplication processing it), transaction processing, anomaly detection (fraud detection)

# Azure Event Hubs REST API
# https://docs.microsoft.com/en-us/rest/api/eventhub/

# The deployment process is:
# 1- Log in to Azure.
# 2- Create a resource group.
# 3- Create an Event Hubs namespace namespace.
# 4- Create an event hub in the namespace you created.
# 5- Get the primary connection string for the namespace.
# 6- Create an application to Send events.
# 7- Create a storage account.
# 8- Get the storage account connection string.
# 9- Create a blob container.
# 10- Create an application to Receive events.


# The following commands are available in PowerShell:
# Get-Command -Module Az.EventHub | Out-GridView

# --------------- 1 --------------- 
Write-Host "---> Log in to Azure" -ForegroundColor Green
# https://docs.microsoft.com/en-us/powershell/azure/authenticate-azureps
Connect-AzAccount -UseDeviceAuthentication
#$tenantId = (Get-AzContext).Tenant.Id

Write-Host "---> Verify registration of the required Azure resource providers" -ForegroundColor Green
# https://docs.microsoft.com/en-us/azure/azure-resource-manager/management/azure-services-resource-providers
@("Microsoft.EventHub", "Microsoft.Storage") | ForEach-Object {
  Register-AzResourceProvider -ProviderNamespace $_
}


# --------------- 2 --------------- 
Write-Host "---> Creating resource group" -ForegroundColor Green
# https://docs.microsoft.com/en-us/powershell/module/az.resources/
$rndResourceGroup = "{0:D5}" -f ( Get-Random -Minimum 0 -Maximum 99999 )
$paramResourceGroup = "rg-testapp1-shared-$rndResourceGroup"
$paramLocation = "westus"
$paramTags = @{Environment = "Test"; Department = "IT" }

$resourceGroup = Get-AzResourceGroup -Name "$paramResourceGroup" -ErrorAction SilentlyContinue
if (-not $resourceGroup) {
  # Create new Resource Group - Get-Help New-AzResourceGroup -Online
  $resourceGroup = New-AzResourceGroup -Name "$paramResourceGroup" -Location "$paramLocation" -Tag $paramTags
}
Write-Host "---> Resource Group details:" -ForegroundColor Green
$resourceGroup


# --------------- 3 --------------- 
Write-Host "---> Creating an Event Hubs namespace" -ForegroundColor Green
$rndehns = "{0:D5}" -f ( Get-Random -Minimum 0 -Maximum 99999 )
# Namespace naming rules: length 6-50, Alphanumerics and hyphens.
$paramEventHubNamespace = "evhns-testapp1-dev-$rndehns"
$paramNamespaceSku = "Basic"  # Event Hubs comes in Basic, Standard, and Dedicated tiers. https://azure.microsoft.com/en-us/pricing/details/event-hubs/
$eventHubNamespace = New-AzEventHubNamespace -ResourceGroupName "$paramResourceGroup" -Name "$paramEventHubNamespace" -Location "$paramLocation" -SkuName $paramNamespaceSku -Tag $paramTags
Write-Host "---> Event Hub Namespace details:" -ForegroundColor Green
$eventHubNamespace


# --------------- 4 --------------- 
Write-Host "---> Creating an event hub in the namespace you created" -ForegroundColor Green
$rndeventhub = "{0:D5}" -f ( Get-Random -Minimum 0 -Maximum 99999 )
$env:varEventHubName = "" # Initialization - With PowerShell's StrictMode set to ON uninitialized variables are flagged as an error.
$env:varEventHubName = "evh-testapp1-dev-$rndeventhub"
$paramRetentionInDays = 1  # Message Retention customization is not available in a Basic Tier Namespace. Change variable $paramNamespaceSku to "Standard" to increase message retention to a maximum of 7 days.
$paramPartitionCount = 4  # Maximum is 32 partitions. You should create as many partitions as you are expecting concurrent subscribing reading applications.
$eventhub = New-AzEventHub -ResourceGroupName "$paramResourceGroup" -NamespaceName "$paramEventHubNamespace" -Name "$env:varEventHubName" -PartitionCount $paramPartitionCount -MessageRetentionInDays $paramRetentionInDays
Write-Host "---> Event Hub details:" -ForegroundColor Green
$eventhub


# --------------- 5 --------------- 
Write-Host "---> Get the primary connection string for the namespace" -ForegroundColor Green
$eventhubKey = Get-AzEventHubKey -ResourceGroupName "$paramResourceGroup" -Namespace "$paramEventHubNamespace" -Name "RootManageSharedAccessKey"
$eventhubKey
$env:varEventHubNamespaceConnection = "" # Initialization - With PowerShell's StrictMode set to ON uninitialized variables are flagged as an error.
$env:varEventHubNamespaceConnection = $eventhubKey.PrimaryConnectionString
Write-Host "---> Primary Connection String" -ForegroundColor Green
$env:varEventHubNamespaceConnection


# --------------- 6 --------------- 
Write-Host "---> Create an application to Send events" -ForegroundColor Green

$runtimeStack = "JS"
if ($runtimeStack -eq "C#") {
  # https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-dotnet-standard-getstarted-send
  $appFolderName = "EventHubsAppSend"
  $appProgramFile = "ProgramEH-Send.cs"
  if ( Test-Path -Path $appFolderName -PathType Container ) { Remove-Item -path $appFolderName -Recurse –force }
  dotnet new console -n $appFolderName
  Set-Location $appFolderName
  dotnet add package Azure.Messaging.EventHubs
  Copy-Item ../$appProgramFile .
  Move-Item $appProgramFile Program.cs -Force
  Write-Host "---> Check your results" -ForegroundColor Green
  dotnet build
  # NOTE: If you receive a Timeout Exception, your environment is probably blocking the TCP ports
  # used for AMQP by default. You need to have ports 5671 and 5672 opened for AMQP connections.
  dotnet run
  Set-Location ..
} 
elseif ($runtimeStack -eq "JS") {
  # https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-node-get-started-send
  if ( Test-Path -Path "node_modules" -PathType Container ) { Remove-Item -path "node_modules" -Recurse –force }
  Remove-Item 'package*.json'
  npm install @azure/event-hubs
  npm install @azure/storage-blob
  npm install @azure/eventhubs-checkpointstore-blob
  node send.js
}
Write-Host "---> In the Azure portal, you can verify that the event hub has received the messages. Switch to Messages view in the Metrics section." -ForegroundColor Green


# --------------- 7 --------------- 
Write-Host "---> Creating a storage account" -ForegroundColor Green
# We need a storage account for the deployed code to live in. Storage accounts also
# need a globally unique name, so we"ll take the first section of a GUID and append it 
# to the storage account name. That should be suitable to make it globally unique.
$rndAcct = "{0:D5}" -f ( Get-Random -Minimum 0 -Maximum 99999 )
# Storage account name must be between 3 and 24 characters in length and use numbers and lower-case letters only.
$paramStorageAccount = "stappdata$rndAcct"
$paramStorageSku = "Standard_LRS"  # https://docs.microsoft.com/en-us/rest/api/storagerp/srp_sku_types
$paramStorageKind = "StorageV2"     # https://docs.microsoft.com/en-us/azure/storage/common/storage-account-overview
$newStorageParams = @{
  ResourceGroupName = $paramResourceGroup
  AccountName       = $paramStorageAccount
  Location          = $paramLocation
  SkuName           = $paramStorageSku
  Tag               = $paramTags
  Kind              = $paramStorageKind
}
# Create new Storage Account - Get-Help New-AzStorageAccount -Online
$storageAccount = New-AzStorageAccount @newStorageParams
Write-Host "---> Storage Account details:" -ForegroundColor Green
$storageAccount


# --------------- 8 --------------- 
Write-Host "---> Get storage account key and connection string" -ForegroundColor Green
$accountKey = Get-AzStorageAccountKey -ResourceGroupName "$paramResourceGroup" -AccountName "$paramStorageAccount" |
Where-Object { $_.KeyName -eq "Key1" } | Select-Object -ExpandProperty Value
$env:varStorageConnectionString = "" # Initialization - With PowerShell's StrictMode set to ON uninitialized variables are flagged as an error.
# Get endpoint suffix using Get-AzEnvironment: Get-AzEnvironment | select Name, StorageEndpointSuffix
$env:varStorageConnectionString = "DefaultEndpointsProtocol=https;AccountName=$paramStorageAccount;AccountKey=$accountKey;EndpointSuffix=core.windows.net"
$env:varStorageConnectionString


# --------------- 9 --------------- 
Write-Host "---> Create a blob container" -ForegroundColor Green
$ctx = $storageAccount.Context
$env:varContainerName = "" # Initialization - With PowerShell's StrictMode set to ON uninitialized variables are flagged as an error.
$env:varContainerName = "messages"
New-AzStorageContainer -Name "$env:varContainerName" -Context $ctx -Permission "Blob"


# --------------- 10 --------------- 
Write-Host "---> Create an application to Receive events" -ForegroundColor Green

if ($runtimeStack -eq "C#") {
  # https://docs.microsoft.com/en-us/azure/event-hubs/event-hubs-dotnet-standard-getstarted-send
  $appFolderName = "EventHubsAppReceive"
  $appProgramFile = "ProgramEH-Receive.cs"
  if ( Test-Path -Path $appFolderName -PathType Container ) { Remove-Item -path $appFolderName -Recurse –force }
  dotnet new console -n $appFolderName
  Set-Location $appFolderName
  dotnet add package Azure.Messaging.EventHubs
  dotnet add package Azure.Messaging.EventHubs.Processor
  Copy-Item ../$appProgramFile .
  Move-Item $appProgramFile Program.cs -Force
  Write-Host "---> Check your results" -ForegroundColor Green
  dotnet build
  # NOTE: If you receive a Timeout Exception, your environment is probably blocking the TCP ports
  # used for AMQP by default. You need to have ports 5671 and 5672 opened for AMQP connections.
  dotnet run
  Set-Location ..
}
elseif ($runtimeStack -eq "JS") {
  node receive.js
}
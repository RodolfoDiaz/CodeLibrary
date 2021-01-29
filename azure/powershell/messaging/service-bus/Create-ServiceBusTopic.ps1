# In StrictMode PowerShell generates a terminating error when the content of 
# an expression or script-block violates basic best-practice coding rules.
Set-StrictMode -Version latest
# Exit immediately if a command exits with a non-zero status.
$ErrorActionPreference = "Stop"

# Azure Service Bus Topics - https://docs.microsoft.com/en-us/azure/service-bus-messaging/service-bus-quickstart-topics-subscriptions-portal

# The deployment process is:
# 1- Log in to Azure.
# 2- Create a resource group.
# 3- Create a Service Bus messaging namespace.
# 4- Create a topic in the namespace.
# 5- Create a few subscriptions to the topic.
# 6- Create a filter to the subscriptions.
# 7- Get the primary connection string for the namespace.
# 8- Create the application.

# The following commands are available in PowerShell:
# Get-Command -Module Az.ServiceBus

# --------------- 1 --------------- 
Write-Host "---> Log in to Azure" -ForegroundColor Green
# https://docs.microsoft.com/en-us/powershell/azure/authenticate-azureps
Connect-AzAccount
#$tenantId = (Get-AzContext).Tenant.Id

Write-Host "---> Verify registration of the required Azure resource providers" -ForegroundColor Green
# Most likely, the providers are already registered, but this will make sure of that.
@("Microsoft.Web", "Microsoft.Storage") | ForEach-Object {
  Register-AzResourceProvider -ProviderNamespace $_
}


# --------------- 2 --------------- 
Write-Host "---> Creating resource group" -ForegroundColor Green
# https://docs.microsoft.com/en-us/powershell/module/az.resources/
$rndResourceGroup = (New-Guid).ToString().Split("-")[0]
$paramResourceGroup = "test_resourcegroup_$rndResourceGroup"
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
Write-Host "---> Creating a Service Bus messaging namespace" -ForegroundColor Green
$rndsbns = (New-Guid).ToString().Split("-")[0]
$paramServiceBusNamespace = "test_servicebusnamespace_$rndsbns"
$serviceBusNamespace = New-AzServiceBusNamespace -ResourceGroupName "$paramResourceGroup" -Name "$paramServiceBusNamespace" -Location "$paramLocation"
Write-Host "---> Service Bus Namespace details:" -ForegroundColor Green
$serviceBusNamespace


# --------------- 4 --------------- 
Write-Host "---> Creating a topic in the namespace" -ForegroundColor Green
$rndtopic = (New-Guid).ToString().Split("-")[0]
$paramServiceBusTopic = "test_servicebustopic_$rndtopic"
$serviceBusTopic = New-AzServiceBusTopic -ResourceGroupName "$paramResourceGroup" -NamespaceName "$paramServiceBusNamespace" -Name "$paramServiceBusTopic"
Write-Host "---> Service Bus Topic details:" -ForegroundColor Green
$serviceBusTopic


# --------------- 5 --------------- 
Write-Host "---> Creating a few subscriptions to the topic." -ForegroundColor Green
$serviceBusSubscription1 = New-AzServiceBusSubscription -ResourceGroupName "$paramResourceGroup" -NamespaceName "$paramServiceBusNamespace" -Topic "$paramServiceBusTopic" -Name "S1"
$serviceBusSubscription1
$serviceBusSubscription2 = New-AzServiceBusSubscription -ResourceGroupName "$paramResourceGroup" -NamespaceName "$paramServiceBusNamespace" -Topic "$paramServiceBusTopic" -Name "S2"
$serviceBusSubscription2
$serviceBusSubscription3 = New-AzServiceBusSubscription -ResourceGroupName "$paramResourceGroup" -NamespaceName "$paramServiceBusNamespace" -Topic "$paramServiceBusTopic" -Name "S3"
$serviceBusSubscription3


# --------------- 6 --------------- 
Write-Host "---> Create a filter to the subscriptions." -ForegroundColor Green
# Create a filter on the first subscription with a filter using custom properties (StoreId is one of Store1, Store2, and Store3).
$serviceBusRule1 = New-AzServiceBusRule -ResourceGroupName "$paramResourceGroup" -NamespaceName "$paramServiceBusNamespace" -Topic "$paramServiceBusTopic" -Subscription "S1" -Name "MyFilter1" -SqlExpression "StoreId IN ('Store1','Store2','Store3')"
$serviceBusRule1
$serviceBusRule2 = New-AzServiceBusRule -ResourceGroupName "$paramResourceGroup" -NamespaceName "$paramServiceBusNamespace" -Topic "$paramServiceBusTopic" -Subscription "S2" -Name "MyFilter2" -SqlExpression "StoreId = 'Store4'"
$serviceBusRule2
$serviceBusRule3 = New-AzServiceBusRule -ResourceGroupName "$paramResourceGroup" -NamespaceName "$paramServiceBusNamespace" -Topic "$paramServiceBusTopic" -Subscription "S3" -Name "MyFilter3" -SqlExpression "StoreId NOT IN ('Store1','Store2','Store3', 'Store4')"
$serviceBusRule3


# --------------- 7 --------------- 
Write-Host "---> Get the primary connection string for the namespace" -ForegroundColor Green
$serviceBusKey = Get-AzServiceBusKey -ResourceGroupName "$paramResourceGroup" -Namespace "$paramServiceBusNamespace" -Name RootManageSharedAccessKey 
$serviceBusKey
$env:primaryConnectionString = "" # Initialization - With PowerShell's StrictMode set to ON uninitialized variables are flagged as an error.
$env:primaryConnectionString = $serviceBusKey.PrimaryConnectionString
Write-Host "---> Primary Connection String" -ForegroundColor Green
$env:primaryConnectionString


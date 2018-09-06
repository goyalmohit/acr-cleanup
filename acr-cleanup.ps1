# This script check and removes the old docker images from the azure container registry

[CmdletBinding()]
Param(
    # Define Service Prinicipal Name for Azure authentication
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String] $ServicePrincipalId,
    
    # Define Service Prinicial key for Azure authentication
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String] $ServicePrincipalPass,

    # Define Tenant ID for Azure authentication
    [Parameter (Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String] $ServicePrincipalTenant,

    # Define Azure Subscription Name
    [Parameter (Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String] $SubscriptionName,
 
    # Define ACR Name
    [Parameter (Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [String] $AzureRegistryName,
 
    # Gets no of days from user; images older than this will be removed
    [Parameter (Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [String] $NoOfDays = "30"
)

Write-Host "Establishing authentication with Azure..."
az login --service-principal -u $ServicePrincipalId -p $ServicePrincipalPass --tenant $ServicePrincipalTenant

if ($SubscriptionName){
    Write-Host "Setting subscription to: $SubscriptionName"
    az account set --subscription $SubscriptionName
}


Write-Host "Checking registry: $AzureRegistryName"
$RepoList = az acr repository list --name $AzureRegistryName --output table
for($index=2; $index -lt $RepoList.length; $index++){
    $RepositoryName = $RepoList[$index]

    Write-Host "Checking for repository: $RepositoryName"
    $RepositoryTags = az acr repository show-tags --name $AzureRegistryName --repository $RepositoryName --output table

    for($item=2; $item -lt $RepositoryTags.length; $item++){
        $RepositoryTagName = $RepositoryTags[$item].ToString().Split('_')        

        $RepositoryTagBuildDay = $RepositoryTagName[-1].ToString().Split('.')[0]
        if($RepositoryTagBuildDay -eq "latest"){
            Write-Host "Skipping image: $RepositoryName/latest"
            continue;
        }

        $RepositoryTagBuildDay = [datetime]::ParseExact($repositorytagbuildday,'yyyyMMdd', $null)
        $ImageName = $RepositoryName + ":" + $RepositoryTags[$item]

        if($RepositoryTagBuildDay -lt $((Get-Date).AddDays(-$NoOfDays))){
            Write-Host "Proceeding to delete image: $ImageName"
            az acr repository delete --name $AzureRegistryName --image $ImageName --yes
        }        
        else{
            Write-Host "Skipping image: $ImageName"
        }
    }
}

Write-Host "Logging out of Azure"
az logout

Write-Host "Script execution finished"


# ACR Cleanup
As part of the Continuous Integration process, new builds are generated which contains certain enhancements or modification or bugfixes. For a containerized application deployment, docker images are created as part of builds which then needs to be uploaded to one of the container registries. Over the time, the registry will get filled up. Also as one use more and more space on the container registry, one needs to pay more and more. This project containes PowerShell script to clean the Azure Container Registry (ACR).

## Getting Started
These instructions will allow you to run the PowerShell script. This script can also be made part of some kind of scheduler to run it at defined frequency. The instructions to configure script as a scheduled job, will vary from type of Scheduler and are not in the scope of this guide. 

## Prerequisites
* You need an Azure Service Principal Account with key to authenticate to Azure Container Registry.
* You need to have Azure CLI and PowerShell installed on the machine, where you are running the script
* The NoOfDays argument works on the assumption that docker images tags based on $(SomeName)_$(Date:yyyyMMdd)$(Rev:.r)
* Alternatively, the NoOfKeptImages argument is based on the date the image was last modified.

## Parameters
* ServicePrincipalId - This is a required parameter. You need to provide service principal account id for this.
* ServicePrincipalPass - This is a required parameter. You need to provide service principal account key for this.
* ServicePrincipalTenant - This is a required parameter. You need to provide Azure Tenant ID in Guid format.
* SubscriptionName - This is not a required parameter. If service account is associated with only one subscription, then you do not need to provide this. If not, this can be used to set the context in which container registry is located.
* AzureRegistryName - This is a required parameter. You need to provide name of the Azure Container Registry.
* NoOfDays - This is not a required parameter. The script will clear docker images older than provided value for this parameter. By default, the value is 30 days.
* NoOfKeptImages - This is not a required parameter.  The script will order images in each repository by date modified, then remove the oldest items beyond the number specified.

## Examples
* Example 1:
.\acr-cleanup.ps1 -ServicePrincipalId db27d2f6-b339-4918-856f-ca0e5c8d0ab5 -ServicePrincipalPass 67cc2733-69c9-46ee-b4d2-d679ceaf77ed -ServicePrincipalTenant fc334bf1-d9f9-4880-85a3-404c7c479c91 -SubscriptionName my-subscription-name -AzureRegistryName my-azure-registry -NoOfDays 90

In this case, script will delete the docker images older than 90 days for every repo in the provided container registry.

* Example 2:
.\acr-cleanup.ps1 -ServicePrincipalId db27d2f6-b339-4918-856f-ca0e5c8d0ab5 -ServicePrincipalPass 67cc2733-69c9-46ee-b4d2-d679ceaf77ed -ServicePrincipalTenant fc334bf1-d9f9-4880-85a3-404c7c479c91 -SubscriptionName my-subscription-name -AzureRegistryName my-azure-registry

In this case, script will delete the docker images older than 30 days for every repo in the provided container registry.

* Example 3:
.\acr-cleanup.ps1 -ServicePrincipalId db27d2f6-b339-4918-856f-ca0e5c8d0ab5 -ServicePrincipalPass 67cc2733-69c9-46ee-b4d2-d679ceaf77ed -ServicePrincipalTenant fc334bf1-d9f9-4880-85a3-404c7c479c91 -AzureRegistryName my-azure-registry

In this case, script will delete the docker images older than 30 days for every repo in the provided container registry.

* Example 4:
.\acr-cleanup.ps1 -ServicePrincipalId db27d2f6-b339-4918-856f-ca0e5c8d0ab5 -ServicePrincipalPass 67cc2733-69c9-46ee-b4d2-d679ceaf77ed -ServicePrincipalTenant fc334bf1-d9f9-4880-85a3-404c7c479c91 -AzureRegistryName my-azure-registry -NoOfKeptImages 5

In this case, script will keep the 5 most recent docker images for every repo in the provided container registry.  Each repo will have no more than 5 images after executing.

## Execute Docker
```bash
docker run \
    -e ServicePrincipalTenant=<value> \
    -e ServicePrincipalId=<value> \
    -e ServicePrincipalPass=<value> \
    -e SubscriptionName=<value> \
    -e AzureRegistryName=<value> \
    -e NoOfDays=30 \
    -e NoOfKeptImages=5 \
    -e DryRun=true \
    <nome_da_imagem_docker>
```
#!/bin/bash

# Carrega as variáveis do arquivo .env, se existir e se ServicePrincipalId não estiver definida
# Loads the variables from the .env file if it exists and if ServicePrincipalId is not set
if [ -f .env ] && [ -z "$ServicePrincipalId" ]; then
    export $(cat .env | grep -v '^#' | xargs) > /dev/null 2>&1
fi

# Função para remover uma imagem do Azure Container Registry
# Function to remove an image from the Azure Container Registry
function remove_image {
    registryName="$1"
    imageName="$2"
    dryRun="$3"

    if [ "$dryRun" = "true" ]; then
        echo "Would have deleted $imageName"  # Simulação de remoção
        # Dry run: Simulating deletion
    else
        echo "Proceeding to delete image: $imageName"  # Remoção real
        # Proceeding to delete the image
        az acr repository delete --name "$registryName" --image "$imageName" --yes
    fi
}

# Verifica se as variáveis necessárias estão definidas
# Checks if the required variables are set
if [ -z "$ServicePrincipalId" ] && [ -z "$ServicePrincipalPass" ] && [ -z "$ServicePrincipalTenant" ]; then
    echo "As variáveis ServicePrincipalId, ServicePrincipalPass e ServicePrincipalTenant devem ser definidas."
    # The variables ServicePrincipalId, ServicePrincipalPass, and ServicePrincipalTenant must be set
    echo "Execute o container Docker com o seguinte comando:"
    # Run the Docker container with the following command
    echo ""
    echo "docker run \\"
    echo "    -e ServicePrincipalTenant=<valor> \\"
    echo "    -e ServicePrincipalId=<valor> \\"
    echo "    -e ServicePrincipalPass=<valor> \\"
    echo "    -e SubscriptionName=<valor> \\"
    echo "    -e AzureRegistryName=<valor> \\"
    echo "    -e NoOfDays=30 \\"
    echo "    -e NoOfKeptImages=5 \\"
    echo "    -e DryRun=true \\"
    echo "    <nome_da_imagem_docker>"
    exit 1
fi

# Autenticação com a Azure
# Authentication with Azure
echo "Estabelecendo autenticação com a Azure..."
# Establishing authentication with Azure
az login --service-principal -u "$ServicePrincipalId" -p "$ServicePrincipalPass" --tenant "$ServicePrincipalTenant"

# Define a assinatura se especificada
# Sets the subscription if specified
if [ -n "$SubscriptionName" ]; then
    echo "Definindo a assinatura para: $SubscriptionName"
    # Setting the subscription to: $SubscriptionName
    az account set --subscription "$SubscriptionName"
fi

# Lista e verifica os repositórios no registro Azure
# Lists and checks the repositories in the Azure registry
echo "Verificando o registro: $AzureRegistryName"
# Checking the registry: $AzureRegistryName
RepoList=($(az acr repository list --name "$AzureRegistryName" --output tsv))
for RepositoryName in "${RepoList[@]}"; do
    echo "Verificando o repositório: $RepositoryName"
    # Checking the repository: $RepositoryName
    RepositoryTags=$(az acr repository show-tags --name "$AzureRegistryName" --repository "$RepositoryName" --orderby time_desc --output tsv)

    # Excluir por contagem se NoOfKeptImages for especificado
    # Delete by count if NoOfKeptImages is specified
    if [ "$NoOfKeptImages" -gt 0 ]; then
        count=0
        for tag in $RepositoryTags; do
            RepositoryTagName=$(echo "$tag" | awk -F_ '{print $NF}' | awk -F. '{print $1}')

            # Ignora tags "latest" e aquelas contendo "migration"
            # Skip "latest" tags and those containing "migration"
            if [ "$RepositoryTagName" = "latest" ] || [[ "$RepositoryTagName" == *"migration"* ]]; then
                echo "Skipping tag: $RepositoryTagName"
                echo "Skipping image: $RepositoryName/$tag"
                continue
            fi

            # Remove imagens além do número especificado em NoOfKeptImages
            # Remove images beyond the number specified in NoOfKeptImages
            if [ $count -ge $NoOfKeptImages ]; then
                ImageName="$RepositoryName:$tag"
                remove_image "$AzureRegistryName" "$ImageName" "$DryRun"
            fi
            ((count++))
        done
    else
        for tag in $RepositoryTags; do
            RepositoryTagName=$(echo "$tag" | awk -F_ '{print $NF}' | awk -F. '{print $1}')
            
            # Ignora tags "latest" e "migration-latest"
            # Skip "latest" and "migration-latest" tags
            if [ "$RepositoryTagName" == "latest" ] || [  "$RepositoryTagName" == "migration-latest" ]; then
                echo "Skipping tag latest"
                echo "Skipping image: $RepositoryName/latest"
                continue
            fi

            # Converte a tag para a data e compara com a data atual menos NoOfDays
            # Convert the tag to date and compare it with the current date minus NoOfDays
            RepositoryTagBuildDay=$(date -d "$RepositoryTagName" "+%Y%m%d")
            ImageName="$RepositoryName:$tag"

            if [ "$RepositoryTagBuildDay" -lt "$(date -d "-$NoOfDays days" "+%Y%m%d")" ]; then
                remove_image "$AzureRegistryName" "$ImageName" "$DryRun"
            else
                echo "Skipping image: $ImageName"
            fi
        done
    fi

    ((index++))
done

# Encerra a sessão da Azure
# Ends the Azure session
echo "Encerrando a sessão da Azure"
# Ending the Azure session
az logout

echo "Execução do script concluída"
# Script execution completed

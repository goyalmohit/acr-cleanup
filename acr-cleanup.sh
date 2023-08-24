#!/bin/bash

# Carrega as variáveis do arquivo .env
if [ -f .env ] && [ -z "$ServicePrincipalId" ]; then
    export $(cat .env | grep -v '^#' | xargs) > /dev/null 2>&1
fi

# Função para remover uma imagem
function remove_image {
    registryName="$1"
    imageName="$2"
    dryRun="$3"

    if [ "$dryRun" = "true" ]; then
        echo "Would have deleted $imageName"
    else
        echo "Proceeding to delete image: $imageName"
        az acr repository delete --name "$registryName" --image "$imageName" --yes
    fi
}

# Verifica se as variáveis estão definidas
if [ -z "$ServicePrincipalId" ] && [ -z "$ServicePrincipalPass" ] && [ -z "$ServicePrincipalTenant" ]; then
    echo "As variáveis ServicePrincipalId, ServicePrincipalPass e ServicePrincipalTenant devem ser definidas."
    echo "Execute o container Docker com o seguinte comando:"
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
echo "Estabelecendo autenticação com a Azure..."
az login --service-principal -u "$ServicePrincipalId" -p "$ServicePrincipalPass" --tenant "$ServicePrincipalTenant"

if [ -n "$SubscriptionName" ]; then
    echo "Definindo a assinatura para: $SubscriptionName"
    az account set --subscription "$SubscriptionName"
fi

echo "Verificando o registro: $AzureRegistryName"
RepoList=($(az acr repository list --name "$AzureRegistryName" --output tsv))
for RepositoryName in "${RepoList[@]}"; do
    echo "Verificando o repositório: $RepositoryName"
    RepositoryTags=$(az acr repository show-tags --name "$AzureRegistryName" --repository "$RepositoryName" --orderby time_desc --output tsv)

    # Excluir por contagem se o usuário especificou NoOfKeptImages
    if [ "$NoOfKeptImages" -gt 0 ]; then
        echo "IF NO OF KEPT IMAGES"

        count=0
        for tag in $RepositoryTags; do
            RepositoryTagName=$(echo "$tag" | awk -F_ '{print $NF}' | awk -F. '{print $1}')

            if [ "$RepositoryTagName" = "latest" ] || [[ "$RepositoryTagName" == *"migration"* ]]; then
                echo "Skipping tag: $RepositoryTagName"
                echo "Skipping image: $RepositoryName/$tag"
                continue
            fi

            if [ $count -ge $NoOfKeptImages ]; then
                ImageName="$RepositoryName:$tag"
                remove_image "$AzureRegistryName" "$ImageName" "$DryRun"
            fi
            ((count++))
        done
    else
        for tag in $RepositoryTags; do
            RepositoryTagName=$(echo "$tag" | awk -F_ '{print $NF}' | awk -F. '{print $1}')
            
            if [ "$RepositoryTagName" == "latest" ] || [  "$RepositoryTagName" == "migration-latest" ]; then
                echo "Skipping tag latest"
                echo "Skipping image: $RepositoryName/latest"
                continue
            fi

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

echo "Encerrando a sessão da Azure"
az logout

echo "Execução do script concluída"
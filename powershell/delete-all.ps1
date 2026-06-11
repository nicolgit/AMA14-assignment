# delete-all.ps1 — teardown for deploy.bicep
# Copy/paste either block into Azure Cloud Shell (PowerShell) to run a single operation.

# 1. Delete the resource group
az group delete --name ama-mro-playground --yes

# 2. Purge all soft-deleted Key Vaults in the current subscription
az keyvault list-deleted --query "[].{name:name, location:properties.location}" -o tsv |
    ForEach-Object {
        $name, $location = $_ -split "`t"
        az keyvault purge --name $name --location $location
    }

# 3. Purge all soft-deleted Azure ML workspaces in the current subscription
az ml workspace list --query "[?softDeleted].{name:name, resourceGroup:resourceGroup}" -o tsv |
    ForEach-Object {
        $name, $resourceGroup = $_ -split "`t"
        if ($name -and $resourceGroup) {
            az ml workspace delete --name $name --resource-group $resourceGroup --permanently-delete
        }
    }

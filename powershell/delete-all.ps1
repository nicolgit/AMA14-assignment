# delete-all.ps1 — teardown for deploy.bicep
# Copy/paste either block into Azure Cloud Shell (PowerShell) to run a single operation.

# Workspace/RG names from deploy.bicep (keep in sync with resourceNameSeed).
$RG = 'ama-mro-playground'

# 1. Permanently delete EVERY Azure ML workspace in the resource group FIRST.
# Deleting the resource group alone leaves each workspace in a SOFT-DELETED state
# (soft delete is ON by default for AML, GA behavior). A soft-deleted workspace
# reserves its name for 14 days and blocks redeploy with the same seed.
# There is NO REST/CLI command to LIST soft-deleted workspaces (only the portal
# "Recently deleted" view shows them), so we hard-delete every ACTIVE workspace
# in the RG by enumeration, using --permanently-delete.
$workspaces = az ml workspace list --resource-group $RG --query "[].name" -o tsv
echo "Permanently deleting $($workspaces.Count) workspace(s)..."
foreach ($ws in $workspaces) {
    if ($ws) {
        az ml workspace delete --name $ws --resource-group $RG --permanently-delete --yes
    }
}

# 2. Delete the resource group (everything else).
az group delete --name $RG --yes

# 3. Purge all soft-deleted Key Vaults in the current subscription.
# Materialize the list into an array first, then iterate over it (avoids holding
# the `az` pipeline open during the long-running purge calls).
$deletedVaults = az keyvault list-deleted --query "[].{name:name, location:properties.location}" -o tsv
echo "Purging $($deletedVaults.Count) deleted vault(s)..."
foreach ($vault in $deletedVaults) {
    $name, $location = $vault -split "`t"
    if ($name) {
        # --no-wait returns immediately instead of polling until the purge completes.
        az keyvault purge --name $name --location $location --no-wait
        echo "Purging vault '$name' in location '$location'..."
    }
}

param location string = resourceGroup().location
param name string
param objectId string
param kvName string

resource kv 'Microsoft.KeyVault/vaults@2021-10-01' existing = {
    name: kvName
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-09-01' = {
    location: location
    name: name
    kind: 'StorageV2'
    sku: {
        name: 'Standard_GRS'
    }
    properties: {
        minimumTlsVersion: 'TLS1_2'
        allowBlobPublicAccess: true
        allowSharedKeyAccess: true
        supportsHttpsTrafficOnly: true
    }
}

resource roleDefinition_Contributor 'Microsoft.Authorization/roleDefinitions@2018-01-01-preview' existing = {
    scope: subscription()
    name: 'b24988ac-6180-42a0-ab88-20f7382dd24c'
}

resource roleAssignment 'Microsoft.Authorization/roleAssignments@2020-04-01-preview' = {
    scope: storageAccount
    name: guid(storageAccount.id, objectId, roleDefinition_Contributor.id)
    properties: {
      roleDefinitionId: roleDefinition_Contributor.id
      principalId: objectId
      principalType: 'ServicePrincipal'
    }
  }

resource serviceBlob 'Microsoft.Storage/storageAccounts/blobServices@2021-09-01' = {
    parent: storageAccount
    name: 'default'
    properties: {
        containerDeleteRetentionPolicy: {
            enabled: true
            days: 7
            allowPermanentDelete: false
        }
    }
}

resource serviceFile 'Microsoft.Storage/storageAccounts/fileServices@2021-09-01' = {
    parent: storageAccount
    name: 'default'
    properties: {
        shareDeleteRetentionPolicy: {
            enabled: true
            days: 7
            allowPermanentDelete: false
        }
    }
}

resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2021-09-01' = {
    parent: serviceBlob
    name: 'batch'
}

resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2021-09-01' = {
    parent: serviceFile
    name: 'batchsmb'
}

resource secret_storageName 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
    parent: kv
    name: 'azure-storage-accountName'
    properties: {
        value: storageAccount.name
        attributes: {
            enabled: true
        }
    }
}

resource secret_storageKey 'Microsoft.KeyVault/vaults/secrets@2021-10-01' = {
    parent: kv
    name: 'azure-storage-accountKey'
    properties: {
        value: storageAccount.listKeys().keys[0].value
        attributes: {
            enabled: true
        }
    }
}

output id string = storageAccount.id
output name string = storageAccount.name
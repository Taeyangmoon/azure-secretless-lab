// Azure Secretless CI/CD Lab - Infrastructure
// The goal is to create zero secrets (passwords / keys / connection strings).
//  - ACR           : admin user disabled, pull only via Managed Identity
//  - Key Vault     : Azure RBAC instead of access policies, read only via Managed Identity
//  - Container App : User-assigned Managed Identity for ACR pull + Key Vault access

targetScope = 'resourceGroup'

@description('Resource name prefix (lowercase letters/digits, max 10 characters)')
@maxLength(10)
param prefix string = 'secretless'

param location string = resourceGroup().location

@description('Demo message stored in Key Vault')
param demoMessage string = 'Hello from Key Vault! This value is not stored in code, environment variables, or GitHub Secrets.'

@description('Initial container image. Replaced by the ACR image when the pipeline runs.')
param containerImage string = 'mcr.microsoft.com/k8se/quickstart:latest'

@description('Port the initial image listens on. The pipeline switches it to the app port (3000).')
param containerPort int = 80

var suffix = uniqueString(resourceGroup().id)
var acrName = toLower('${prefix}acr${take(suffix, 8)}')
var keyVaultName = toLower('${prefix}-kv-${take(suffix, 6)}')
var secretName = 'demo-message'

// Built-in role IDs
var acrPullRoleId = '7f951dda-4ed3-4680-a7ca-43fe172d538d' // AcrPull
var kvSecretsUserRoleId = '4633458b-17de-408a-b874-0445c86b69e6' // Key Vault Secrets User

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: '${prefix}-log-${take(suffix, 6)}'
  location: location
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// Managed Identity used by the app (user-assigned)
// Creating it before the Container App lets us grant permissions in advance.
resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${prefix}-id-app'
  location: location
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: { name: 'Basic' }
  properties: {
    adminUserEnabled: false // no registry username/password
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true // RBAC instead of access policies
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
  }
}

resource demoSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: secretName
  properties: {
    value: demoMessage
  }
}

resource acrPullAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: acr
  name: guid(acr.id, appIdentity.id, acrPullRoleId)
  properties: {
    principalId: appIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', acrPullRoleId)
  }
}

resource kvSecretsUserAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, appIdentity.id, kvSecretsUserRoleId)
  properties: {
    principalId: appIdentity.properties.principalId
    principalType: 'ServicePrincipal'
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', kvSecretsUserRoleId)
  }
}

resource containerEnv 'Microsoft.App/managedEnvironments@2024-03-01' = {
  name: '${prefix}-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

resource containerApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: '${prefix}-app'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${appIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: containerPort
        transport: 'auto'
      }
      // Registry authentication also uses the Managed Identity (no username/password)
      registries: [
        {
          server: acr.properties.loginServer
          identity: appIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'app'
          image: containerImage
          resources: {
            cpu: json('0.25')
            memory: '0.5Gi'
          }
          env: [
            // All of these are non-secret settings.
            { name: 'AZURE_CLIENT_ID', value: appIdentity.properties.clientId }
            { name: 'KEY_VAULT_URL', value: keyVault.properties.vaultUri }
            { name: 'SECRET_NAME', value: secretName }
            { name: 'APP_VERSION', value: 'initial' }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
  dependsOn: [
    acrPullAssignment
    kvSecretsUserAssignment
  ]
}

output resourceGroupName string = resourceGroup().name
output acrName string = acr.name
output acrLoginServer string = acr.properties.loginServer
output keyVaultName string = keyVault.name
output containerAppName string = containerApp.name
output appIdentityName string = appIdentity.name
output appUrl string = 'https://${containerApp.properties.configuration.ingress.fqdn}'

// Azure Secretless CI/CD Lab - 인프라
// 시크릿(비밀번호/키/연결 문자열)을 하나도 만들지 않는 것이 목표입니다.
//  - ACR           : 관리자 계정(admin user) 비활성화, Managed Identity 로만 Pull
//  - Key Vault     : 액세스 정책 대신 Azure RBAC, Managed Identity 로만 읽기
//  - Container App : User-assigned Managed Identity 로 ACR Pull + Key Vault 접근

targetScope = 'resourceGroup'

@description('리소스 이름 접두사 (소문자/숫자, 최대 10자)')
@maxLength(10)
param prefix string = 'secretless'

param location string = resourceGroup().location

@description('Key Vault 에 저장할 데모 메시지')
param demoMessage string = 'Hello from Key Vault! 이 값은 코드/환경변수/GitHub Secrets 어디에도 없습니다.'

@description('초기 컨테이너 이미지. 파이프라인이 실행되면 ACR 이미지로 교체됩니다.')
param containerImage string = 'mcr.microsoft.com/k8se/quickstart:latest'

@description('초기 이미지가 수신하는 포트. 파이프라인이 앱 포트(3000)로 변경합니다.')
param containerPort int = 80

var suffix = uniqueString(resourceGroup().id)
var acrName = toLower('${prefix}acr${take(suffix, 8)}')
var keyVaultName = toLower('${prefix}-kv-${take(suffix, 6)}')
var secretName = 'demo-message'

// 내장 역할 ID
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

// 앱이 사용할 Managed Identity (User-assigned)
// 앱(Container App)보다 먼저 만들어 두면 권한을 미리 부여할 수 있습니다.
resource appIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: '${prefix}-id-app'
  location: location
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: { name: 'Basic' }
  properties: {
    adminUserEnabled: false // 레지스트리 사용자/비밀번호를 쓰지 않는다
  }
}

resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: keyVaultName
  location: location
  properties: {
    sku: { family: 'A', name: 'standard' }
    tenantId: subscription().tenantId
    enableRbacAuthorization: true // 액세스 정책 대신 RBAC
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
      // 레지스트리 인증도 Managed Identity 로 한다 (username/password 없음)
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
            // 아래 값들은 모두 "비밀이 아닌" 설정값입니다.
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

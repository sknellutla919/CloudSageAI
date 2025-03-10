param location string = 'westeurope'
param acrName string = 'jcchatbotacr'
param logAnalyticsName string = 'jc-chatbot-log-workspace'
param apimName string = 'jc-chatbot-apim-jcapi'
param searchServiceName string = 'jcchatbot-search'
param openaiName string = 'jcchatbot-openai'
param contentSafetyName string = 'jc-chatbot-content-safety'
param identityName string = 'jc-chatbot-identity'



// Parameters for the keys
@secure()
param insightsKey string
@secure()
param searchKey string
@secure()
param openaiKey string
@secure()
param contentSafetyKey string
@secure()
param cosmosConnection string

// Reference existing resources
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: logAnalyticsName
}

resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' existing = {
  name: acrName
}

resource apim 'Microsoft.ApiManagement/service@2023-03-01-preview' existing = {
  name: apimName
}

resource containerIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' existing = {
  name: identityName
}

// Container Apps Environment
resource containerAppEnvironment 'Microsoft.App/managedEnvironments@2023-05-01' = {
  name: 'jc-chatbot-env'
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: listKeys(logAnalytics.id, '2020-03-01-preview').primarySharedKey
      }
    }
  }
}



// API Container App
resource apiContainerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'jc-chatbot-api'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 3001
        transport: 'http'
      }
      registries: [
        {
          server: '${acrName}.azurecr.io'
          identity: containerIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'api'
          image: '${acrName}.azurecr.io/chatbot-api:latest'
          resources: {
            cpu: '0.5'
            memory: '1Gi'
          }
          env: [
            {
              name: 'AZURE_OPENAI_ENDPOINT'
              value: 'https://${openaiName}.openai.azure.com/'
            }
            {
              name: 'AZURE_OPENAI_API_KEY'
              value: openaiKey
            }
            {
              name: 'AZURE_COGNITIVE_SEARCH_ENDPOINT'
              value: 'https://${searchServiceName}.search.windows.net'
            }
            {
              name: 'AZURE_COGNITIVE_SEARCH_API_KEY'
              value: searchKey
            }
            {
              name: 'AZURE_COGNITIVE_SEARCH_INDEX'
              value: 'jira_confluence_knowledge'
            }
            {
              name: 'AZURE_CONTENT_SAFETY_ENDPOINT'
              value: 'https://${contentSafetyName}.cognitiveservices.azure.com/'
            }
            {
              name: 'AZURE_CONTENT_SAFETY_KEY'
              value: contentSafetyKey
            }
            {
              name: 'AZURE_COSMOSDB_CONNECTION_STRING'
              value: cosmosConnection
            }
            {
              name: 'AZURE_AD_CLIENT_ID'
              value: ''
            }
            {
              name: 'AZURE_AD_CLIENT_SECRET'
              value: ''
            }
            {
              name: 'AZURE_AD_TENANT_ID'
              value: ''
            }
            {
              name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
              value: insightsKey
            }
            {
              name: 'NEXTAUTH_URL'
              value: 'https://jc-chatbot-api.${containerAppEnvironment.properties.defaultDomain}'
            }
            {
              name: 'NEXTAUTH_SECRET'
              value: '${uniqueString(resourceGroup().id)}'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

// UI Container App
resource uiContainerApp 'Microsoft.App/containerApps@2023-05-01' = {
  name: 'jc-chatbot-ui'
  location: location
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${containerIdentity.id}': {}
    }
  }
  properties: {
    managedEnvironmentId: containerAppEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 3000
        transport: 'http'
      }
      registries: [
        {
          server: '${acrName}.azurecr.io'
          identity: containerIdentity.id
        }
      ]
    }
    template: {
      containers: [
        {
          name: 'ui'
          image: '${acrName}.azurecr.io/chatbot-ui:latest'
          resources: {
            cpu: '0.5'
            memory: '1Gi'
          }
          env: [
            {
              name: 'NEXT_PUBLIC_API_BASE_URL'
              value: 'https://${apimName}.azure-api.net/chatbot'
            }
            {
              name: 'AZURE_AD_CLIENT_ID'
              value: ''
            }
            {
              name: 'AZURE_AD_CLIENT_SECRET'
              value: ''
            }
            {
              name: 'AZURE_AD_TENANT_ID'
              value: ''
            }
            {
              name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
              value: insightsKey
            }
            {
              name: 'NEXTAUTH_URL'
              value: 'https://jc-chatbot-ui.${containerAppEnvironment.properties.defaultDomain}'
            }
            {
              name: 'NEXTAUTH_SECRET'
              value: '${uniqueString(resourceGroup().id)}'
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 3
      }
    }
  }
}

// APIM configuration
resource chatbotApi 'Microsoft.ApiManagement/service/apis@2023-03-01-preview' = {
  parent: apim
  name: 'chatbot-api'
  properties: {
    displayName: 'CloudSageAI Chatbot API'
    apiRevision: '1'
    subscriptionRequired: false
    protocols: [
      'https'
    ]
    path: 'chatbot'
  }
}

resource chatOperation 'Microsoft.ApiManagement/service/apis/operations@2023-03-01-preview' = {
  parent: chatbotApi
  name: 'chat'
  properties: {
    displayName: 'Chat API'
    method: 'POST'
    urlTemplate: '/api/chat'
    request: {
      representations: [
        {
          contentType: 'application/json'
        }
      ]
    }
  }
}

resource chatPolicy 'Microsoft.ApiManagement/service/apis/operations/policies@2023-03-01-preview' = {
  parent: chatOperation
  name: 'policy'
  properties: {
    value: '<policies><inbound><base /><cors><allowed-origins><origin>https://${uiContainerApp.properties.configuration.ingress.fqdn}</origin></allowed-origins><allowed-methods><method>POST</method><method>OPTIONS</method></allowed-methods><allowed-headers><header>Content-Type</header><header>Authorization</header></allowed-headers><expose-headers><header>*</header></expose-headers></cors><set-backend-service base-url="https://${apiContainerApp.properties.configuration.ingress.fqdn}" /></inbound><backend><base /></backend><outbound><base /></outbound><on-error><base /></on-error></policies>'
    format: 'xml'
  }
  dependsOn: [
    apiContainerApp
    uiContainerApp
  ]
}

// Output URLs
output uiUrl string = 'https://${uiContainerApp.properties.configuration.ingress.fqdn}'
output apiUrl string = 'https://${apiContainerApp.properties.configuration.ingress.fqdn}'
output apimUrl string = 'https://${apimName}.azure-api.net/chatbot'

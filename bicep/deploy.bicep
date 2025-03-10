targetScope = 'resourceGroup'
param location string = 'westeurope'


param openaiName string = 'jcchatbot-openai'
param cosmosdbName string = 'jcchatbotcosmos'
param logAnalyticsName string = 'jc-chatbot-log-workspace'
param searchServiceName string = 'jcchatbot-search'
param appInsightsName string = 'jc-chatbot-app-insights'
param apimName string = 'jc-chatbot-apim-jcapi'
param appServicePlanName string = 'jc-chatbot-api-plan'
param functionAppName string = 'jc-chatbot-api'
param storageAccountName string = 'jcchatbotstorage919'
param contentSafetyName string = 'jc-chatbot-content-safety'
param contentSafetyLocation string = 'westeurope' 
param visionName string = 'jc-chatbot-vision'
param documentIntelligenceName string = 'jc-chatbot-doc-intelligence'
param disableLocalAuth bool = false
param publicNetworkAccess string = 'Enabled'
param acrName string = 'jcchatbotacr'

//flatten function
@description('Name for the Azure Function App')
param flattenFunctionAppName string = 'jc-chatbot-flatten-func'

// Network parameters
param vnetName string = 'jc-chatbot-vnet'
param vnetAddressPrefix string = '10.0.0.0/16'
param appSubnetName string = 'app-subnet'
param appSubnetAddressPrefix string = '10.0.4.0/24'
param dataSubnetName string = 'data-subnet'
param dataSubnetAddressPrefix string = '10.0.5.0/24'

// ✅ VNet and Subnet Resources
resource vnet 'Microsoft.Network/virtualNetworks@2022-07-01' = {
  name: vnetName
  location: location
  properties: {
    addressSpace: {
      addressPrefixes: [
        vnetAddressPrefix
      ]
    }
    subnets: [
      {
        name: appSubnetName
        properties: {
          addressPrefix: appSubnetAddressPrefix
          delegations: [
            {
              name: 'delegation'
              properties: {
                serviceName: 'Microsoft.Web/serverFarms'
              }
            }
          ]
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.AzureCosmosDB'
            }
          ]
        }
      }
      {
        name: dataSubnetName
        properties: {
          addressPrefix: dataSubnetAddressPrefix
          serviceEndpoints: [
            {
              service: 'Microsoft.Storage'
            }
            {
              service: 'Microsoft.AzureCosmosDB'
            }
            {
              service: 'Microsoft.CognitiveServices'
            }
          ]
        }
      }
    ]
  }
}

// ✅ DEPLOY LOGGING & MONITORING FIRST
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: logAnalyticsName
  location: location
  properties: {
    retentionInDays: 30
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource appInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: appInsightsName
  location: location
  kind: 'web'
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
  }
}

// ✅ DEPLOY STORAGE & DATABASE RESOURCES
resource cosmosdb 'Microsoft.DocumentDB/databaseAccounts@2023-03-15' = {
  name: cosmosdbName
  location: location
  kind: 'GlobalDocumentDB'
  properties: {
    databaseAccountOfferType: 'Standard'
    // Network configuration for CosmosDB
    isVirtualNetworkFilterEnabled: true
    virtualNetworkRules: [
      {
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, appSubnetName)
        ignoreMissingVNetServiceEndpoint: false
      }
      {
        id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, dataSubnetName)
        ignoreMissingVNetServiceEndpoint: false
      }
    ]
  }
  dependsOn: [
    vnet
  ]
}

// Create Database and Container
resource cosmosDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2023-03-15' = {
  parent: cosmosdb
  name: 'jcchatbot'
  properties: {
    resource: {
      id: 'jcchatbot'
    }
  }
}

resource cosmosContainer 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2023-03-15' = {
  parent: cosmosDatabase
  name: 'knowledgebase'
  properties: {
    resource: {
      id: 'knowledgebase'
      partitionKey: {
        paths: [
          '/id'
        ]
        kind: 'Hash'
      }
      indexingPolicy: {
        indexingMode: 'consistent'
      }
    }
  }
}

// Private endpoint for CosmosDB to Search connection
resource cosmosDBPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${cosmosdbName}-search-pe'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: '${cosmosdbName}-search-privatelink'
        properties: {
          privateLinkServiceId: cosmosdb.id
          groupIds: [
            'Sql'  // Use 'Sql' for CosmosDB SQL API
          ]
        }
      }
    ]
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, dataSubnetName)
    }
  }
  dependsOn: [
    vnet
    cosmosdb
  ]
}

// Private DNS Zone for CosmosDB
resource cosmosDBPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.documents.azure.com'
  location: 'global'
}

// VNet link for CosmosDB private DNS zone
resource cosmosDBPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: cosmosDBPrivateDnsZone
  name: '${cosmosdbName}-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
  dependsOn: [
    vnet
  ]
}

// Private DNS Zone Group for CosmosDB
resource cosmosDBPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: cosmosDBPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: cosmosDBPrivateDnsZone.id
        }
      }
    ]
  }
}



// Diagnostic Settings for CosmosDB
resource cosmosdbDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: cosmosdb
  name: '${cosmosdbName}-diagnostics'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'DataPlaneRequests'
        enabled: true
      }
      {
        category: 'QueryRuntimeStatistics'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'Requests'
        enabled: true
      }
    ]
  }
  dependsOn: [
    cosmosdb  
    logAnalytics
  ]
}

resource storageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: storageAccountName
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    networkAcls: {
      defaultAction: 'Deny'
      virtualNetworkRules: [
        {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, appSubnetName)
          action: 'Allow'
        }
        {
          id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, dataSubnetName)
          action: 'Allow'
        }
      ]
      bypass: 'AzureServices'
    }
  }
  dependsOn: [
    vnet
  ]
}

// Diagnostic Settings for Storage Account
resource storageDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: storageAccount
  name: '${storageAccountName}-diagnostics'
  properties: {
    workspaceId: logAnalytics.id
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
      {
        category: 'Capacity'
        enabled: true
      }
    ]
  }
}

// ✅ DEPLOY ACR
resource acr 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: acrName
  location: location
  sku: {
    name: 'Basic' // Keep Basic tier for cost savings
  }
  properties: {
    adminUserEnabled: true
  }
}

// Diagnostic Settings for ACR
resource acrDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: acr
  name: '${acrName}-diagnostics'
  properties: {
    workspaceId: logAnalytics.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// User-assigned managed identity for Container Apps
resource containerAppIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: 'jc-chatbot-identity'
  location: location
}

// Role assignment for AcrPull
resource identityAcrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(containerAppIdentity.id, acr.id, 'AcrPull')
  scope: acr
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull role
    principalId: containerAppIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    acr
    containerAppIdentity
  ]
}



// ✅ DEPLOY APP SERVICE PLAN AND FUNCTION APP
resource appServicePlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: appServicePlanName
  location: location
  kind: 'Linux'
  sku: {
    name: 'P1v2' // Using Premium tier for VNet integration (can use P1v2, P2v2, P3v2)
  }
  properties: {
    reserved: true // Required for Linux
  }
}



// Consumption Plan for Function App
resource flattenFunctionPlan 'Microsoft.Web/serverfarms@2022-09-01' = {
  name: 'jcchatbot-flatten-func-plan'
  location: location
  kind: 'Linux'
  sku: {
    name: 'P1v2' // Using Premium tier for VNet integration (can use P1v2, P2v2, P3v2)
  }
  properties: {
    reserved: true // Required for Linux
  }
}


// Secondary storage account for Function App files
resource functionStorageAccount 'Microsoft.Storage/storageAccounts@2021-06-01' = {
  name: 'mlchatbotstoragefunc'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    // Allow public access for Function App initialization
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

resource flattenFunctionStorage 'Microsoft.Storage/storageAccounts@2022-09-01' = {
  name: 'jcchatbotfuncflatten'
  location: location
  sku: {
    name: 'Standard_LRS'
  }
  kind: 'StorageV2'
  properties: {
    minimumTlsVersion: 'TLS1_2'
    supportsHttpsTrafficOnly: true
    // Allow public access for Function App initialization
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}


// ✅ DEPLOY FUNCTION APP
resource functionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: functionAppName
  location: location
  kind: 'functionapp,linux' 
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: appServicePlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'python|3.9'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'APPINSIGHTS_INSTRUMENTATIONKEY'
          value: appInsights.properties.InstrumentationKey
        }
        {
          name: 'APPLICATIONINSIGHTS_CONNECTION_STRING'
          value: appInsights.properties.ConnectionString
        }
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccount.name};AccountKey=${listKeys(functionStorageAccount.id, functionStorageAccount.apiVersion).keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${functionStorageAccount.name};AccountKey=${listKeys(functionStorageAccount.id, functionStorageAccount.apiVersion).keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(functionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1'
        }
        {
          name: 'COSMOSDB_URL'
          value: cosmosdb.properties.documentEndpoint
        }
        {
          name: 'COSMOSDB_KEY'
          value: listKeys(cosmosdb.id, cosmosdb.apiVersion).primaryMasterKey
        }
        {
          name: 'COSMOSDB_DATABASE'
          value: cosmosDatabase.name
        }
        {
          name: 'COSMOSDB_CONTAINER'
          value: cosmosContainer.name
        }
        {
          name: 'AZURE_VISION_ENDPOINT'
          value: vision.properties.endpoint
        }
        {
          name: 'AZURE_VISION_KEY'
          value: listKeys(vision.id, vision.apiVersion).key1
        }
        {
          name: 'AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT'
          value: documentIntelligence.properties.endpoint
        }
        {
          name: 'AZURE_DOCUMENT_INTELLIGENCE_KEY'
          value: listKeys(documentIntelligence.id, documentIntelligence.apiVersion).key1
        }
        {
          name: 'JIRA_API_URL'
          value: 'https://cloudsageai.atlassian.net/rest/api/3'
        }
        {
          name: 'JIRA_API_USERNAME'
          value: 'santoshk.nellutla@gmail.com'
        }
        {
          name: 'JIRA_API_TOKEN'
          value: '-'
        }
        {
          name: 'CONFLUENCE_API_URL'
          value: 'https://cloudsageai.atlassian.net/wiki'
        }
        {
          name: 'CONFLUENCE_API_USERNAME'
          value: 'santoshk.nellutla@gmail.com'
        }
        {
          name: 'CONFLUENCE_API_TOKEN'
          value: ''
        }
      ]
    }
  }
  dependsOn: [
    storageAccount
    appServicePlan
    appInsights
    cosmosdb      
    vision        
    documentIntelligence 
  ]
}

// ✅ DEPLOY FUNCTION APP
resource flattenFunctionApp 'Microsoft.Web/sites@2022-09-01' = {
  name: flattenFunctionAppName
  location: location
  kind: 'functionapp,linux' 
  identity: {
    type: 'SystemAssigned'
  }
  properties: {
    serverFarmId: flattenFunctionPlan.id
    httpsOnly: true
    siteConfig: {
      linuxFxVersion: 'python|3.9'
      minTlsVersion: '1.2'
      ftpsState: 'Disabled'
      appSettings: [
        {
          name: 'AzureWebJobsStorage'
          value: 'DefaultEndpointsProtocol=https;AccountName=${flattenFunctionStorage.name};AccountKey=${listKeys(flattenFunctionStorage.id, flattenFunctionStorage.apiVersion).keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTAZUREFILECONNECTIONSTRING'
          value: 'DefaultEndpointsProtocol=https;AccountName=${flattenFunctionStorage.name};AccountKey=${listKeys(flattenFunctionStorage.id, flattenFunctionStorage.apiVersion).keys[0].value};EndpointSuffix=core.windows.net'
        }
        {
          name: 'WEBSITE_CONTENTSHARE'
          value: toLower(flattenFunctionAppName)
        }
        {
          name: 'FUNCTIONS_EXTENSION_VERSION'
          value: '~4'
        }
        {
          name: 'FUNCTIONS_WORKER_RUNTIME'
          value: 'python'
        }
        {
          name: 'WEBSITE_VNET_ROUTE_ALL'
          value: '1'
        }
        {
          name: 'SOURCE_COSMOSDB_URL'
          value: cosmosdb.properties.documentEndpoint
        }
        {
          name: 'SOURCE_COSMOSDB_KEY'
          value: listKeys(cosmosdb.id, '2022-05-15').primaryMasterKey
        }
        {
          name: 'SOURCE_COSMOSDB_DATABASE'
          value: 'jcchatbot'
        }
        {
          name: 'SOURCE_COSMOSDB_CONTAINER'
          value: 'knowledgebase'
        }
        {
          name: 'TARGET_COSMOSDB_CONTAINER'
          value: 'flatten'
        }
      ]
    }
  }
  dependsOn: [
    storageAccount
    appServicePlan
    appInsights
    cosmosdb      
    vision        
    documentIntelligence 
  ]
}
 

// Function App VNet Integration
resource functionVnetIntegration 'Microsoft.Web/sites/networkConfig@2022-09-01' = {
  parent: functionApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, appSubnetName)
    swiftSupported: true
  }
  dependsOn: [
    vnet
  ]
}

resource flattenFunctionVnetIntegration 'Microsoft.Web/sites/networkConfig@2022-09-01' = {
  parent: flattenFunctionApp
  name: 'virtualNetwork'
  properties: {
    subnetResourceId: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, appSubnetName)
    swiftSupported: true
  }
  dependsOn: [
    vnet
  ]
}

// Diagnostic Settings for Function App
resource functionAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: functionApp
  name: '${functionAppName}-diagnostics'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource flattenFunctionAppDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: flattenFunctionApp
  name: '${flattenFunctionAppName}-diagnostics'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'FunctionAppLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ✅ DEPLOY AI & COGNITIVE SERVICES
resource openai 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: openaiName
  location: location
  kind: 'OpenAI'
  identity: {
    type: 'SystemAssigned'  // Add this line to enable system-assigned identity
  }
  properties: {
    customSubDomainName: toLower(openaiName)
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
    }
    disableLocalAuth: disableLocalAuth
  }
  sku: {
    name: 'S0'
  }
}

// OpenAI Deployment for GPT-4-turbo
resource openaiDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
  parent: openai
  name: 'gpt-4-turbo'
  sku: {
    name: 'Standard'
    capacity: 1
  }
  properties: {
    model: {
      format: 'OpenAI'
      name: 'gpt-4-turbo'
      version: '1106-preview'
    }
    raiPolicyName: 'Microsoft.Default'
  }
}

// Configure data connection between OpenAI and Search
resource openaiSearchConnection 'Microsoft.CognitiveServices/accounts/connections@2023-05-01' = {
  parent: openai
  name: 'search-connection'
  properties: {
    target: cognitiveSearch.id
    authType: 'SystemAssigned'
    connectionType: 'AzureSearch'
    allocationPolicy: {
      type: 'LlmRequest'
    }
  }
  dependsOn: [
    openaiDeployment
    cognitiveSearch
  ]
}

// Diagnostic Settings for OpenAI
resource openaiDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: openai
  name: '${openaiName}-diagnostics'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'Audit'
        enabled: true
      }
      {
        category: 'RequestResponse'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
  dependsOn: [
    openai        
    logAnalytics  
  ]
}

// Add this to reference the existing search service
resource cognitiveSearch 'Microsoft.Search/searchServices@2023-11-01' existing = {
  name: searchServiceName
}

// Search datasource that connects to CosmosDB
resource searchDataSource 'Microsoft.Search/searchServices/dataSources@2023-11-01' = {
  parent: cognitiveSearch
  name: 'cosmosdb-datasource'
  properties: {
    type: 'cosmosdb'
    credentials: {
      connectionString: 'AccountEndpoint=${cosmosdb.properties.documentEndpoint};AccountKey=${listKeys(cosmosdb.id, '2023-03-15').primaryMasterKey};Database=jcchatbot'
    }
    container: {
      name: 'flatten'
      query: ''
    }
    dataChangeDetectionPolicy: {
      '@odata.type': '#Microsoft.Azure.Search.HighWaterMarkChangeDetectionPolicy'
      highWaterMarkColumnName: '_ts'
    }
  }
  dependsOn: [
    cosmosdb
    cognitiveSearch
    cosmosDBPrivateEndpoint  // Add dependency on the private endpoint
    searchPrivateEndpoint    // Add dependency on the search private endpoint
  ]
}

// Role assignment for OpenAI to access Search
resource openaiSearchRoleAssignment 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  name: guid(openai.id, cognitiveSearch.id, 'SearchIndexDataReader')
  scope: cognitiveSearch
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '1407120a-92aa-4202-b7e9-c0e197c71c8f')  // Search Index Data Reader
    principalId: openai.identity.principalId
    principalType: 'ServicePrincipal'
  }
  dependsOn: [
    openai
    cognitiveSearch
  ]
}


// Private Endpoint for Search Service (if not already present in your bicep)
resource searchPrivateEndpoint 'Microsoft.Network/privateEndpoints@2023-05-01' = {
  name: '${searchServiceName}-private-endpoint'
  location: location
  properties: {
    privateLinkServiceConnections: [
      {
        name: '${searchServiceName}-privatelink'
        properties: {
          privateLinkServiceId: cognitiveSearch.id
          groupIds: [
            'searchService'
          ]
        }
      }
    ]
    subnet: {
      id: resourceId('Microsoft.Network/virtualNetworks/subnets', vnetName, dataSubnetName)
    }
  }
  dependsOn: [
    vnet
    cognitiveSearch
  ]
}

// Private DNS Zone for Search (if not already present)
resource searchPrivateDnsZone 'Microsoft.Network/privateDnsZones@2020-06-01' = {
  name: 'privatelink.search.windows.net'
  location: 'global'
}

// VNet link for Search private DNS zone
resource searchPrivateDnsZoneVnetLink 'Microsoft.Network/privateDnsZones/virtualNetworkLinks@2020-06-01' = {
  parent: searchPrivateDnsZone
  name: '${searchServiceName}-vnet-link'
  location: 'global'
  properties: {
    registrationEnabled: false
    virtualNetwork: {
      id: vnet.id
    }
  }
  dependsOn: [
    vnet
  ]
}

// Private DNS Zone Group for Search
resource searchPrivateDnsZoneGroup 'Microsoft.Network/privateEndpoints/privateDnsZoneGroups@2023-05-01' = {
  parent: searchPrivateEndpoint
  name: 'default'
  properties: {
    privateDnsZoneConfigs: [
      {
        name: 'config1'
        properties: {
          privateDnsZoneId: searchPrivateDnsZone.id
        }
      }
    ]
  }
}


// Diagnostic Settings for Cognitive Search
resource cognitiveSearchDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: cognitiveSearch
  name: '${searchServiceName}-diagnostics'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'OperationLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
  dependsOn: [
    logAnalytics
  ]
}

resource contentSafety 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: contentSafetyName
  location: contentSafetyLocation
  kind: 'ContentSafety'
  sku: {
    name: 'S0'
  }
  properties: {
    customSubDomainName: toLower(contentSafetyName)
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
    }
    disableLocalAuth: disableLocalAuth
  }
}

// Diagnostic Settings for Content Safety
resource contentSafetyDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: contentSafety
  name: '${contentSafetyName}-diagnostics'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'Audit'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource vision 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: visionName
  location: location
  kind: 'ComputerVision'
  sku: {
    name: 'S1'
  }
  properties: {
    customSubDomainName: toLower(visionName)
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow' 
    }
    disableLocalAuth: disableLocalAuth
  }
}

// Diagnostic Settings for Vision
resource visionDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: vision
  name: '${visionName}-diagnostics'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'Audit'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

resource documentIntelligence 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: documentIntelligenceName
  location: location
  kind: 'FormRecognizer'
  properties: {
    customSubDomainName: toLower(documentIntelligenceName)
    disableLocalAuth: disableLocalAuth
    publicNetworkAccess: publicNetworkAccess
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
  sku: {
    name: 'S0'
  }
}

// Diagnostic Settings for Document Intelligence
resource documentIntelligenceDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: documentIntelligence
  name: '${documentIntelligenceName}-diagnostics'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'Audit'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// ✅ DEPLOY API MANAGEMENT (APIM)
resource apim 'Microsoft.ApiManagement/service@2023-03-01-preview' = {
  name: apimName
  location: location
  sku: {
    name: 'Consumption' // Changed to Consumption for easier deployment and lower cost
    capacity: 0
  }
  properties: {
    publisherName: 'Chatbot DevOps'
    publisherEmail: 'admin@example.com'
  }
}

// Diagnostic Settings for APIM
resource apimDiagnostics 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: apim
  name: '${apimName}-diagnostics'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        category: 'GatewayLogs'
        enabled: true
      }
    ]
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
  }
}

// Output values
output vnetId string = vnet.id
output openaiId string = openai.id
output cosmosdbId string = cosmosdb.id
output logAnalyticsId string = logAnalytics.id
output appInsightsId string = appInsights.id
output apimId string = apim.id
output appServicePlanId string = appServicePlan.id
output functionAppId string = functionApp.id
output storageAccountId string = storageAccount.id
output contentSafetyEndpoint string = contentSafety.properties.endpoint
output visionEndpoint string = vision.properties.endpoint
output documentIntelligenceEndpoint string = documentIntelligence.properties.endpoint
output acrId string = acr.id
output containerAppIdentityId string = containerAppIdentity.id
output openaiDeploymentId string = openaiDeployment.id
output openaiDeploymentName string = openaiDeployment.name

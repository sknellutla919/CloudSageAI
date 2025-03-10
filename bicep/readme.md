# CloudSageAI - Infrastructure as Code (Bicep)

This directory contains the Bicep templates used to deploy the CloudSageAI infrastructure on Azure. These templates automate the provisioning of all required resources in a consistent and repeatable manner.

## 📋 Overview

The Bicep templates in this directory define the complete infrastructure for CloudSageAI, including Azure OpenAI, Cognitive Search, Cosmos DB, Container Apps, API Management, and supporting services. The templates are designed to be deployed in a specific sequence to ensure proper dependency management and avoid deployment conflicts.

## 🔧 Key Components

### 1. `search.bicep` - Search Service Deployment

This template deploys:
- Azure Cognitive Search service

This is deployed first in the pipeline to ensure it's available when needed by dependent resources.

### 2. `deploy.bicep` - Main Infrastructure Deployment

This comprehensive template deploys:
- Virtual Network and Subnets
- Azure Cosmos DB
- OpenAI Service with GPT-4 Deployment
- Content Safety
- Vision and Document Intelligence
- Function Apps
- API Management
- Container Registry
- Azure Monitor Resources (Log Analytics, App Insights)
- Private Endpoints and DNS Zones
- Data Integration Between Services

### 3. `container-apps.bicep` - Application Deployment

This template deploys:
- Container App Environment
- API Container App
- UI Container App
- API Management Integration

## 📦 Deployment Sequence and Dependencies

### Critical Deployment Order

The deployment sequence is specifically designed to handle resource dependencies and avoid "not found" conflicts:

1. **Deploy Search First (`search.bicep`)**
   - Azure Search requires time to provision fully
   - Other resources will reference this search service, so it needs to exist first

2. **Deploy Main Infrastructure (`deploy.bicep`)**
   - References the existing search service
   - Sets up all core infrastructure and integrations

3. **Deploy Container Apps (`container-apps.bicep`)**
   - Depends on the infrastructure being fully deployed
   - Configures applications with necessary connection information

### Dependency Management Strategy

We implement several strategies to manage dependencies effectively:

1. **Resource References**
   - Use `existing` keyword to reference resources created in previous deployments
   
   ```bicep
   resource cognitiveSearch 'Microsoft.Search/searchServices@2023-11-01' existing = {
     name: searchServiceName
   }
   ```

2. **Explicit Dependencies**
   - Use `dependsOn` property to ensure proper order of resource creation
   
   ```bicep
   resource searchDataSource 'Microsoft.Search/searchServices/dataSources@2023-11-01' = {
     parent: cognitiveSearch
     name: 'cosmosdb-datasource'
     properties: {
       // properties
     }
     dependsOn: [
       cosmosdb
       cognitiveSearch
     ]
   }
   ```

3. **Parent-Child Relationships**
   - Use `parent` property to establish resource hierarchies
   
   ```bicep
   resource openaiDeployment 'Microsoft.CognitiveServices/accounts/deployments@2023-05-01' = {
     parent: openai
     name: 'gpt-4-turbo'
     // properties
   }
   ```

4. **Deployment Scripts**
   - Use deployment scripts for complex operations that can't be easily modeled in Bicep
   
   ```bicep
   resource searchIndexSetupScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
     name: 'setupSearchIndexAndIndexer'
     // properties
   }
   ```

## 🛠️ Common Issues and Solutions

### 1. "Resource Not Found" Conflicts

**Issue:** Dependencies attempt to reference resources that don't exist yet, like trying to link to a search service that hasn't finished provisioning.

**Solution:**
- Deploy search services first in a separate deployment
- Use the `existing` keyword in subsequent deployments
- Add sufficient delays between dependent deployments
- Implement retry logic in deployment scripts

```yaml
# Example pipeline stage with delay
- stage: DeploySearchService
  displayName: "Deploy Search Service"
  jobs:
    - job: DeploySearch
      steps:
        - task: AzureCLI@2
          inputs:
            azureSubscription: "CloudSageAI-SP"
            scriptType: 'bash'
            inlineScript: |
              az deployment group create \
                --resource-group $(resourceGroupName) \
                --template-file bicep/search.bicep \
                --parameters location=$(location) cognitiveSearchName=$(searchServiceName)
              
              echo "Waiting for Search Service to be fully provisioned (2 minutes)..."
              sleep 120
```

### 2. Private Endpoint Configuration Issues

**Issue:** Private endpoints may not properly connect to services, causing connectivity issues.

**Solution:**
- Ensure VNet and subnets are created first
- Properly configure DNS zones
- Add explicit dependencies between private endpoints and the services they connect to
- Verify that subnet delegation is set up correctly

```bicep
// Example correct private endpoint configuration
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
```

### 3. OpenAI Deployment Limitations

**Issue:** OpenAI model deployments may fail if quota is insufficient or configuration is incorrect.

**Solution:**
- Ensure quota is requested and approved for the desired models
- Use the correct model names and versions
- Handle errors gracefully in the deployment process
- Consider using conditional deployment based on region availability

```bicep
// Example OpenAI deployment with correct configuration
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
```

### 4. Azure Cognitive Search Index and Indexer Creation

**Issue:** Creating search index and indexer via Bicep can be challenging due to complex schema requirements.

**Solution:**
- Use deployment scripts to create indexes and indexers
- Leverage the REST API through curl commands in deployment scripts
- Ensure proper error handling in scripts
- Validate index and indexer configurations before deployment

```bicep
// Example search index setup using deployment script
resource searchIndexSetupScript 'Microsoft.Resources/deploymentScripts@2020-10-01' = {
  name: 'setupSearchIndexAndIndexer'
  location: location
  kind: 'AzureCLI'
  properties: {
    azCliVersion: '2.30.0'
    scriptContent: '''
      #!/bin/bash
      
      # Set variables from environment
      SEARCH_SERVICE_NAME=$SEARCH_SERVICE_NAME
      SEARCH_ADMIN_KEY=$SEARCH_ADMIN_KEY
      
      # Create the index
      curl -X PUT "https://$SEARCH_SERVICE_NAME.search.windows.net/indexes/jira_confluence_knowledge?api-version=2023-07-01-preview" \
        -H "Content-Type: application/json" \
        -H "api-key: $SEARCH_ADMIN_KEY" \
        -d '{
          "name": "jira_confluence_knowledge",
          "fields": [
            {"name": "id", "type": "Edm.String", "key": true, "searchable": false},
            // additional fields
          ]
        }'
      
      # More commands...
    '''
    environmentVariables: [
      {
        name: 'SEARCH_SERVICE_NAME'
        value: searchServiceName
      }
      {
        name: 'SEARCH_ADMIN_KEY'
        secureValue: listKeys(cognitiveSearch.id, cognitiveSearch.apiVersion).primaryKey
      }
    ]
  }
}
```

### 5. System-Assigned Identity for Service Connections

**Issue:** When connecting OpenAI to Cognitive Search, a system-assigned identity is required but may not be properly configured.

**Solution:**
- Ensure the OpenAI resource has system-assigned identity enabled
- Assign the appropriate role to the identity
- Add explicit `dependsOn` for role assignments before creating connections

```bicep
// Enable system-assigned identity for OpenAI
resource openai 'Microsoft.CognitiveServices/accounts@2023-05-01' = {
  name: openaiName
  location: location
  kind: 'OpenAI'
  identity: {
    type: 'SystemAssigned'  // Enable system-assigned identity
  }
  // other properties
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
```

## 📦 Deployment Guide

### Prerequisites

- Azure CLI installed
- Bicep CLI installed
- Azure subscription with required permissions
- Service principal for deployment

### Manual Deployment Steps

1. **Deploy Search Service**
   ```bash
   az deployment group create \
     --resource-group your-rg-name \
     --template-file bicep/search.bicep \
     --parameters location=westeurope cognitiveSearchName=your-search-name
   ```

2. **Wait for Search Service to be fully provisioned (2-3 minutes)**

3. **Deploy Main Infrastructure**
   ```bash
   az deployment group create \
     --resource-group your-rg-name \
     --template-file bicep/deploy.bicep \
     --parameters location=westeurope openaiName=your-openai-name cosmosdbName=your-cosmos-name
   ```

4. **Deploy Container Apps**
   ```bash
   # First, get required keys and endpoints
   SEARCH_KEY=$(az search admin-key show --resource-group your-rg-name --service-name your-search-name --query primaryKey -o tsv)
   OPENAI_KEY=$(az cognitiveservices account keys list --resource-group your-rg-name --name your-openai-name --query key1 -o tsv)
   
   # Deploy container apps
   az deployment group create \
     --resource-group your-rg-name \
     --template-file bicep/container-apps.bicep \
     --parameters searchKey=$SEARCH_KEY openaiKey=$OPENAI_KEY
   ```

### Using Azure DevOps Pipeline

See the `azure-pipeline-complete.yml` file for a complete automated deployment pipeline that handles the correct deployment order and dependencies.

## 🔎 Customization

### Modifying Resource Names

Update the following parameters in your deployment:

```bash
az deployment group create \
  --resource-group your-rg-name \
  --template-file bicep/deploy.bicep \
  --parameters \
    location=westeurope \
    openaiName=your-custom-openai-name \
    cosmosdbName=your-custom-cosmos-name \
    searchServiceName=your-custom-search-name \
    functionAppName=your-custom-function-app-name
```

### Changing SKUs/Pricing Tiers

Modify the `sku` properties in the Bicep templates:

```bicep
resource cognitiveSearch 'Microsoft.Search/searchServices@2023-11-01' = {
  name: searchServiceName
  location: location
  sku: {
    name: 'standard'  // Change to 'basic' or 'standard2' as needed
  }
  // other properties
}
```

## 🔗 Links to Related Documentation

- [Bicep Documentation](https://docs.microsoft.com/en-us/azure/azure-resource-manager/bicep/)
- [Azure OpenAI Resource Provider](https://docs.microsoft.com/en-us/azure/templates/microsoft.cognitiveservices/accounts)
- [Azure Cognitive Search Resource Provider](https://docs.microsoft.com/en-us/azure/templates/microsoft.search/searchservices)
- [Azure Container Apps Resource Provider](https://docs.microsoft.com/en-us/azure/templates/microsoft.app/containerapps)
- [Azure Cosmos DB Resource Provider](https://docs.microsoft.com/en-us/azure/templates/microsoft.documentdb/databaseaccounts)
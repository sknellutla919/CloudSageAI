#!/bin/bash
# Search Index Indexer and DataSource Creation Script

# Required parameters
SEARCH_SERVICE_NAME=$1
$COSMOS_ACCOUNT_NAME = $2
RESOURCE_GROUP=$3

# Validate parameters
if [ -z "$SEARCH_SERVICE_NAME" ] || [ -z "$RESOURCE_GROUP" ]; then
  echo "Usage: $0 <search-service-name> <cosmos-account-name> <resource-group>"
  exit 1
fi

# Get the search admin key
echo "Getting search admin key..."
SEARCH_ADMIN_KEY=$(az search admin-key show --service-name $SEARCH_SERVICE_NAME --resource-group $RESOURCE_GROUP --query primaryKey -o tsv)
COSMOS_ENDPOINT=$(az cosmosdb keys list --name $COSMOS_ACCOUNT_NAME --resource-group $RESOURCE_GROUP --query primaryMasterKey -o tsv)
AccountKey=$(az cosmosdb keys list --name $COSMOS_ACCOUNT_NAME --resource-group $RESOURCE_GROUP --query primaryMasterKey -o tsv)
if [ -z "$SEARCH_KEY" ]; then
  echo "Error: Failed to retrieve search key for $SEARCH_SERVICE_NAME"
  exit 1
fi

echo "Creating search index..."
INDEX_RESPONSE=$(curl -s -X PUT "https://$SEARCH_SERVICE_NAME.search.windows.net/indexes/jira_confluence_knowledge?api-version=2020-06-30" \
  -H "Content-Type: application/json" \
  -H "api-key: $SEARCH_KEY" \
  -d '{
    "name": "jira_confluence_knowledge",
    "fields": [
      {
        "name": "id",
        "type": "Edm.String",
        "key": true,
        "searchable": false,
        "filterable": true
      },
      {
        "name": "title",
        "type": "Edm.String",
        "searchable": true,
        "filterable": true
      },
      {
        "name": "content",
        "type": "Edm.String",
        "searchable": true
      },
      {
        "name": "source",
        "type": "Edm.String",
        "searchable": true,
        "filterable": true
      },
      {
        "name": "lastUpdated",
        "type": "Edm.DateTimeOffset",
        "searchable": false,
        "filterable": true,
        "sortable": true
      }
    ]
  }')

echo "Index creation response: $INDEX_RESPONSE"

echo "Adding sample document..."
DOC_RESPONSE=$(curl -s -X POST "https://$SEARCH_SERVICE_NAME.search.windows.net/indexes/jira_confluence_knowledge/docs/index?api-version=2020-06-30" \
  -H "Content-Type: application/json" \
  -H "api-key: $SEARCH_KEY" \
  -d '{
    "value": [
      {
        "id": "test-doc-1",
        "title": "Kubernetes Setup Guide",
        "content": "This guide explains how to set up a Kubernetes cluster. First, you need to install kubectl. Then, you need to choose a platform such as AKS, GKE, or EKS. For Azure, use az aks create command to create a cluster.",
        "source": "Confluence",
        "lastUpdated": "2023-01-01T00:00:00Z"
      }
    ]
  }')

  # Create the data source
echo "Creating search data source..."
DATA_SOURCE=$(curl -X PUT "https://$SEARCH_SERVICE_NAME.search.windows.net/datasources/cosmosdb-datasource?api-version=2023-07-01-preview" \
  -H "Content-Type: application/json" \
  -H "api-key: $SEARCH_ADMIN_KEY" \
  -d '{
    "name": "cosmosdb-datasource",
    "type": "cosmosdb",
    "credentials": {
        "connectionString": "AccountEndpoint='$COSMOS_ENDPOINT';AccountKey='$COSMOS_KEY';Database=jcchatbot"
    },
    "container": {
        "name": "flatten",
        "query": null
    },
    "dataChangeDetectionPolicy": {
        "@odata.type": "#Microsoft.Azure.Search.SoftDeleteColumnDeletionDetectionPolicy",
        "softDeleteColumnName": "f",
        "softDeleteMarkerValue": "f"
    }
  }')
  # Create the indexer
echo "Creating search indexer..."
SEARCH_INDEXER=$(curl -X PUT "https://$SEARCH_SERVICE_NAME.search.windows.net/indexers/cosmosdb-indexer?api-version=2023-07-01-preview" \
  -H "Content-Type: application/json" \
  -H "api-key: $SEARCH_ADMIN_KEY" \
  -d '{
    "name": "cosmosdb-indexer",
    "dataSourceName": "cosmosdb-datasource",
    "targetIndexName": "jira_confluence_knowledge",
    "schedule": {
        "interval": "PT5M"
    },
    "parameters": {
        "maxFailedItems": 10,
      "maxFailedItemsPerBatch": 5,
      "base64EncodeKeys": false
    },
    "fieldMappings": [
        {"sourceFieldName": "id", "targetFieldName": "id"},
      {"sourceFieldName": "key", "targetFieldName": "key"},
      {"sourceFieldName": "summary", "targetFieldName": "summary"},
      {"sourceFieldName": "description", "targetFieldName": "description"},
      {"sourceFieldName": "title", "targetFieldName": "title"},
      {"sourceFieldName": "content", "targetFieldName": "content"}
    ]
  }')
        


echo "Document creation response: $DOC_RESPONSE"

echo "Search Indexer creation response: $SEARCH_INDEXER"

echo "Data source creation response: $DATA_SOURCE"

echo "Search index setup completed"

echo "Setup complete!"

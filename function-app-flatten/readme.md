# CloudSageAI - Data Flattening Function

This Azure Function App is responsible for flattening and normalizing the complex data structures from Jira and Confluence stored in Cosmos DB to optimize them for Azure Cognitive Search indexing.

## 📋 Overview

The data flattening function serves as a critical data transformation component in the CloudSageAI architecture. It processes the raw, nested data structures that come from Jira and Confluence, converts them into a flattened format that is optimized for search indexing, and stores the processed data in a separate Cosmos DB container that serves as the source for Azure Cognitive Search.

## 🔧 Key Components

### 1. `flatten_cosmos.py` - Main Flattening Function

The core functionality is implemented in the `flatten_cosmos.py` file, which:

- Reads complex document structures from the source Cosmos DB container
- Processes nested fields like Jira descriptions with Atlassian Document Format
- Extracts and normalizes text content
- Writes flattened documents to the target Cosmos DB container
- Maintains proper field mappings for search indexing

### 2. `function.json` - Function Configuration

This file configures the Azure Function trigger:

- Sets up a timer trigger to run at specified intervals
- Configures the function to run on startup for initial data processing

### 3. `requirements.txt` - Dependencies

Lists all Python package dependencies required for the function.

## 📦 Technical Implementation

### Jira Document Format Processing

The function flattens the nested Atlassian Document Format (ADF) into plain text:

```python
def flatten_description(desc):
    """
    Flattens the nested doc object from Jira.
    Expected input format:
      {
        "type": "doc",
        "version": 1,
        "content": [
          {
            "type": "paragraph",
            "content": [
              {"type": "text", "text": "some text"}
            ]
          },
          // possibly more blocks…
        ]
      }
    Returns a string with the concatenated text.
    """
    if not isinstance(desc, dict):
        return desc
    if desc.get("type") != "doc" or "content" not in desc:
        return ""
    lines = []
    for block in desc["content"]:
        if block.get("type") == "paragraph" and "content" in block:
            paragraph_texts = [inline.get("text", "") for inline in block["content"] if inline.get("type") == "text"]
            if paragraph_texts:
                lines.append(" ".join(paragraph_texts))
    return "\n".join(lines)
```

### Data Transformation Pipeline

The function implements a complete data transformation pipeline:

```python
def main(timer: func.TimerRequest) -> None:
    logging.info("FlattenCosmosData timer function triggered.")
    try:
        # Source Cosmos DB details
        source_url = os.environ["SOURCE_COSMOSDB_URL"]
        source_key = os.environ["SOURCE_COSMOSDB_KEY"]
        source_db = os.environ["SOURCE_COSMOSDB_DATABASE"]
        source_container_name = os.environ["SOURCE_COSMOSDB_CONTAINER"]

        # Target Cosmos DB details
        target_url = os.environ["TARGET_COSMOSDB_URL"]
        target_key = os.environ["TARGET_COSMOSDB_KEY"]
        target_db = os.environ["TARGET_COSMOSDB_DATABASE"]
        target_container_name = os.environ["TARGET_COSMOSDB_CONTAINER"]

        source_client = CosmosClient(source_url, credential=source_key)
        target_client = CosmosClient(target_url, credential=target_key)

        source_database = source_client.get_database_client(source_db)
        source_container = source_database.get_container_client(source_container_name)
        target_database = target_client.get_database_client(target_db)
        target_container = target_database.get_container_client(target_container_name)

        # Retrieve all documents from the source container
        documents = list(source_container.query_items(
            query="SELECT * FROM c",
            enable_cross_partition_query=True
        ))
        logging.info(f"Found {len(documents)} documents in source container.")

        processed_docs = []
        for doc in documents:
            if "fields" in doc:
                fields = doc["fields"]
                # Promote Jira summary to top level if it exists
                if "summary" in fields:
                    doc["summary"] = fields["summary"]
                # Flatten Jira description and promote to top level
                if "description" in fields:
                    flattened = flatten_description(fields["description"])
                    fields["description"] = flattened
                    doc["description"] = flattened

            # Explicit handling for Confluence pages
            if "title" in doc:
                doc["title"] = doc["title"]
            if "body" in doc and "storage" in doc["body"]:
                doc["content"] = doc["body"]["storage"]["value"]

            processed_docs.append(doc)

        count = 0
        for doc in processed_docs:
            target_container.upsert_item(doc)
            count += 1

        logging.info(f"Successfully processed and upserted {count} documents.")
    except Exception as e:
        logging.error(f"Error processing documents: {str(e)}")
```

## 🛠️ Development Guide

### Local Development Setup

1. Clone the repository
2. Navigate to the `/function-app-flatten` directory
3. Create a `.env` file with the following variables:

```
SOURCE_COSMOSDB_URL=your-cosmos-db-url
SOURCE_COSMOSDB_KEY=your-cosmos-db-key
SOURCE_COSMOSDB_DATABASE=jcchatbot
SOURCE_COSMOSDB_CONTAINER=knowledgebase
TARGET_COSMOSDB_URL=your-cosmos-db-url
TARGET_COSMOSDB_KEY=your-cosmos-db-key
TARGET_COSMOSDB_DATABASE=jcchatbot
TARGET_COSMOSDB_CONTAINER=flatten
```

4. Install dependencies:
```bash
pip install -r requirements.txt
```

5. Run the function locally using Azure Functions Core Tools:
```bash
func start
```

### Making Changes

When modifying the data flattening logic:

1. **Field Mapping**: Ensure consistent field mapping between source and target
2. **Content Extraction**: Handle complex markup and formats appropriately
3. **Error Handling**: Implement robust error handling for malformed documents
4. **Performance**: Optimize for large document sets with batching

## 📊 Monitoring and Debugging

### Logs

Function logs can be viewed in:
- Azure Portal (Function App > Logs)
- Application Insights traces
- Local console during development

### Key Performance Metrics

Monitor the following metrics:
- Execution duration
- Number of documents processed
- Success/failure rate
- Document transformation time

### Common Issues

1. **Document Format Changes**
   - Update the flattening logic to handle new formats
   - Add special case handling for unusual content

2. **Processing Errors**
   - Log detailed error information for debugging
   - Implement graceful failure for individual documents

3. **Performance Issues**
   - Implement batching for large document sets
   - Consider incremental processing

## 🔒 Security Considerations

- Database keys are stored securely in Application Settings
-
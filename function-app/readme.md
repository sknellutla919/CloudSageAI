# CloudSageAI - Data Extraction Function

This Azure Function App is responsible for extracting, processing, and storing data from Jira and Confluence into Azure Cosmos DB and Azure Cognitive Search.

## 📋 Overview

The data extraction function serves as the ETL (Extract, Transform, Load) component of CloudSageAI. It periodically connects to Jira and Confluence APIs, extracts ticket and document information, processes any attached images or PDFs using Azure Vision and Document Intelligence, and stores the structured data in Cosmos DB for later indexing by Azure Cognitive Search.

## 🔧 Key Components

### 1. `fetch_data.py` - Main Extraction Function

The core functionality is implemented in the `fetch_data.py` file, which:

- Connects to Jira and Confluence APIs using configured credentials
- Extracts ticket/page data including attachments
- Processes images using Azure Vision to extract text
- Processes PDFs using Document Intelligence to extract content
- Stores all data in a structured format in Cosmos DB

### 2. `function.json` - Function Configuration

This file configures the Azure Function trigger:

- Sets up a timer trigger to run at specified intervals
- Configures the function to run on startup for initial data load

### 3. `requirements.txt` - Dependencies

Lists all Python package dependencies required for the function.

## 📦 Technical Implementation

### Jira & Confluence Data Extraction

The function extracts data from Jira and Confluence through their REST APIs:

```python
def fetch_jira_tickets(first_run=False):
    logging.info("Fetching Jira tickets...")
    auth = HTTPBasicAuth(JIRA_USERNAME, JIRA_API_TOKEN)
    jql_query = "ORDER BY created DESC" if first_run else f"updated >= '{(datetime.utcnow() - timedelta(days=1)).strftime('%Y-%m-%d')}'"
    response = requests.get(f"{JIRA_API_URL}/search?jql={jql_query}&fields=summary,description,attachment", auth=auth)
    
    if response.status_code == 200:
        issues = response.json().get("issues", [])
        # Process attachments and extract data
        # ...
        return issues
    
    logging.error(f"Failed to fetch Jira tickets: {response.status_code} {response.text}")
    return []
```

```python
def fetch_confluence_pages(first_run=False):
    logging.info("Fetching Confluence pages...")
    auth = HTTPBasicAuth(CONFLUENCE_USERNAME, CONFLUENCE_API_TOKEN)
    response = requests.get(
        f"{CONFLUENCE_API_URL}/rest/api/content?type=page&expand=version,metadata.labels,body.storage,children.attachment",
        auth=auth
    )
    
    if response.status_code == 200:
        pages = response.json().get("results", [])
        # Process attachments and extract data
        # ...
        return pages
    
    logging.error(f"Failed to fetch Confluence pages: {response.status_code} {response.text}")
    return []
```

### Image Processing with Azure Vision

The function uses Azure Vision to extract text from images:

```python
def analyze_image(image_url, base_url=None):
    # Handle relative/absolute URLs
    if not image_url.startswith("http"):
        if base_url:
            image_url = base_url.rstrip("/") + "/" + image_url.lstrip("/")
        else:
            logging.error("Relative image URL provided but no base_url given.")
            return None

    logging.info(f"Processing image: {image_url}")
    
    # Fetch the image
    image_response = requests.get(image_url, auth=HTTPBasicAuth(JIRA_USERNAME, JIRA_API_TOKEN))
    if image_response.status_code != 200:
        logging.error(f"Failed to fetch image from URL: {image_url} - Status code: {image_response.status_code}")
        return None
    image_data = image_response.content
    
    # Analyze with Vision
    try:
        analysis_response = vision_client.analyze(image_data, visual_features=["Tags"])
    except Exception as e:
        logging.error(f"Vision analysis failed: {str(e)}")
        return None

    # Extract tags and return
    tags = []
    if "tagsResult" in analysis_response and "values" in analysis_response["tagsResult"]:
        tags = [tag["name"] for tag in analysis_response["tagsResult"]["values"]]
    return tags
```

### PDF Processing with Document Intelligence

The function processes PDFs to extract text content:

```python
def analyze_pdf(pdf_url):
    logging.info(f"Processing PDF: {pdf_url}")
    response = document_intelligence_client.begin_analyze_document("prebuilt-layout", document_url=pdf_url)
    result = response.result()
    if result:
        logging.info("PDF processed successfully")
        return result.content
    
    logging.warning("PDF processing failed")
    return None
```

### Data Storage in Cosmos DB

Processed data is stored in Cosmos DB for later indexing:

```python
def store_data_in_cosmosdb(data):
    logging.info("Storing data in CosmosDB...")
    for record in data:
        try:
            container.upsert_item(record)
        except Exception as e:
            logging.error(f"Error inserting record: {str(e)}")
```

## 🛠️ Development Guide

### Local Development Setup

1. Clone the repository
2. Navigate to the `/function-app` directory
3. Create a `.env` file with the following variables:

```
JIRA_API_URL=https://your-jira-instance.atlassian.net/rest/api/3
JIRA_API_USERNAME=your-jira-email
JIRA_API_TOKEN=your-jira-api-token
CONFLUENCE_API_URL=https://your-confluence-instance.atlassian.net/wiki
CONFLUENCE_API_USERNAME=your-confluence-email
CONFLUENCE_API_TOKEN=your-confluence-api-token
COSMOSDB_URL=your-cosmos-db-url
COSMOSDB_KEY=your-cosmos-db-key
COSMOSDB_DATABASE=jcchatbot
COSMOSDB_CONTAINER=knowledgebase
AZURE_VISION_ENDPOINT=your-vision-endpoint
AZURE_VISION_KEY=your-vision-key
AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT=your-document-intelligence-endpoint
AZURE_DOCUMENT_INTELLIGENCE_KEY=your-document-intelligence-key
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

When modifying the data extraction logic:

1. **Error Handling**: Ensure robust error handling for API calls and processing
2. **Rate Limiting**: Implement backoff strategies for API rate limits
3. **Data Structure**: Maintain consistent data structure for effective search indexing
4. **Incremental Updates**: Optimize for incremental data extraction to minimize API usage

## 📊 Monitoring and Debugging

### Logs

Function logs can be viewed in:
- Azure Portal (Function App > Logs)
- Application Insights traces
- Local console during development

### Key Performance Metrics

Monitor the following metrics:
- Execution duration
- Success/failure rate
- Number of items processed
- API response times

### Common Issues

1. **API Authentication Failures**
   - Verify credentials are correct and not expired
   - Check API endpoint URLs

2. **Throttling/Rate Limiting**
   - Implement exponential backoff
   - Reduce batch sizes

3. **Processing Errors**
   - Handle different image/PDF formats gracefully
   - Implement fallback strategies

## 🔒 Security Considerations

- API tokens are stored securely in Application Settings
- Private endpoints ensure secure service-to-service communication
- VNet integration provides network isolation
- Managed identities are used where possible

## 🔄 Scheduled Execution

The function is configured to run:
- On initial deployment
- Every 5 minutes via timer trigger

This schedule can be adjusted in `function.json` based on data freshness requirements.

## 🔗 Links to Related Documentation

- [Azure Functions Python Developer Guide](https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-python)
- [Jira REST API Documentation](https://developer.atlassian.com/cloud/jira/platform/rest/v3/intro/)
- [Confluence REST API Documentation](https://developer.atlassian.com/cloud/confluence/rest/intro/)
- [Azure Vision Documentation](https://docs.microsoft.com/en-us/azure/cognitive-services/computer-vision/)
- [Azure Document Intelligence Documentation](https://docs.microsoft.com/en-us/azure/applied-ai-services/form-recognizer/)
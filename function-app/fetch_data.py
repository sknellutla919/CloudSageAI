import os
import json
import requests
import azure.functions as func
import logging
from azure.cosmos import CosmosClient
from datetime import datetime, timedelta
from azure.ai.vision import VisionClient
from azure.ai.documentintelligence import DocumentIntelligenceClient

# Environment Variables
JIRA_API_URL = os.getenv("JIRA_API_URL")
JIRA_USERNAME = os.getenv("JIRA_USERNAME")
JIRA_API_TOKEN = os.getenv("JIRA_API_TOKEN")
CONFLUENCE_API_URL = os.getenv("CONFLUENCE_API_URL")
CONFLUENCE_USERNAME = os.getenv("CONFLUENCE_USERNAME")
CONFLUENCE_API_TOKEN = os.getenv("CONFLUENCE_API_TOKEN")
COSMOSDB_URL = os.getenv("COSMOSDB_URL")
COSMOSDB_KEY = os.getenv("COSMOSDB_KEY")
COSMOSDB_DATABASE = os.getenv("COSMOSDB_DATABASE")
COSMOSDB_CONTAINER = os.getenv("COSMOSDB_CONTAINER")
AZURE_VISION_ENDPOINT = os.getenv("AZURE_VISION_ENDPOINT")
AZURE_VISION_KEY = os.getenv("AZURE_VISION_KEY")
AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT = os.getenv("AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT")
AZURE_DOCUMENT_INTELLIGENCE_KEY = os.getenv("AZURE_DOCUMENT_INTELLIGENCE_KEY")

# Initialize Logging
logging.basicConfig(level=logging.INFO)

# Initialize CosmosDB Client
client = CosmosClient(COSMOSDB_URL, credential=COSMOSDB_KEY)
database = client.get_database_client(COSMOSDB_DATABASE)
container = database.get_container_client(COSMOSDB_CONTAINER)

# Initialize Azure Vision & Document Intelligence Clients
vision_client = VisionClient(endpoint=AZURE_VISION_ENDPOINT, credential=AZURE_VISION_KEY)
document_intelligence_client = DocumentIntelligenceClient(endpoint=AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT, credential=AZURE_DOCUMENT_INTELLIGENCE_KEY)

# Function to check if this is the first run
def is_first_run():
    logging.info("Checking if this is the first data fetch...")
    return container.query_items(query="SELECT VALUE COUNT(1) FROM c", enable_cross_partition_query=True).__next__() == 0

# Function to analyze images using Azure AI Vision
def analyze_image(image_url):
    logging.info(f"Processing image: {image_url}")
    response = vision_client.read(image_url)
    if response:
        logging.info("Image processed successfully")
        return response.content
    logging.warning("Image processing failed")
    return None

# Function to analyze PDFs using Azure Document Intelligence
def analyze_pdf(pdf_url):
    logging.info(f"Processing PDF: {pdf_url}")
    response = document_intelligence_client.begin_analyze_document("prebuilt-layout", document_url=pdf_url)
    result = response.result()
    if result:
        logging.info("PDF processed successfully")
        return result.content
    logging.warning("PDF processing failed")
    return None

# Function to fetch Jira tickets including image & document analysis
def fetch_jira_tickets(first_run=False):
    logging.info("Fetching Jira tickets...")
    headers = {"Authorization": f"Basic {JIRA_API_TOKEN}", "Content-Type": "application/json"}
    jql_query = "ORDER BY created DESC" if first_run else f"updated >= '{(datetime.utcnow() - timedelta(days=1)).strftime('%Y-%m-%d')}'"
    response = requests.get(f"{JIRA_API_URL}/search?jql={jql_query}&fields=summary,description,attachment", headers=headers)

    if response.status_code == 200:
        issues = response.json().get("issues", [])
        for issue in issues:
            attachments = issue.get("fields", {}).get("attachment", [])
            for att in attachments:
                if att["mimeType"].startswith("image/"):
                    extracted_text = analyze_image(att["content"])
                    issue["image_text"] = extracted_text if extracted_text else "No text extracted."
                elif att["mimeType"].startswith("application/pdf"):
                    extracted_pdf_text = analyze_pdf(att["content"])
                    issue["pdf_text"] = extracted_pdf_text if extracted_pdf_text else "No structured data extracted."

        logging.info(f"Fetched {len(issues)} Jira tickets")
        return issues
    logging.error("Failed to fetch Jira tickets")
    return []

# Function to fetch Confluence pages including image & document analysis
def fetch_confluence_pages(first_run=False):
    logging.info("Fetching Confluence pages...")
    headers = {"Authorization": f"Basic {CONFLUENCE_API_TOKEN}", "Content-Type": "application/json"}
    response = requests.get(
        f"{CONFLUENCE_API_URL}/rest/api/content?type=page&expand=version,metadata.labels,body.storage,children.attachment",
        headers=headers
    )

    if response.status_code == 200:
        pages = response.json().get("results", [])
        for page in pages:
            attachments = page.get("children", {}).get("attachment", {}).get("results", [])
            for att in attachments:
                if att["metadata"]["mediaType"].startswith("image/"):
                    extracted_text = analyze_image(att["_links"]["download"])
                    page["image_text"] = extracted_text if extracted_text else "No text extracted."
                elif att["metadata"]["mediaType"].startswith("application/pdf"):
                    extracted_pdf_text = analyze_pdf(att["_links"]["download"])
                    page["pdf_text"] = extracted_pdf_text if extracted_pdf_text else "No structured data extracted."

        logging.info(f"Fetched {len(pages)} Confluence pages")
        return pages
    logging.error("Failed to fetch Confluence pages")
    return []

# Function to store data in CosmosDB
def store_data_in_cosmosdb(data):
    logging.info("Storing data in CosmosDB...")
    for record in data:
        try:
            container.upsert_item(record)
        except Exception as e:
            logging.error(f"Error inserting record: {str(e)}")

app = func.FunctionApp()

@app.function_name("fetch_data")
@app.schedule(schedule="0 */1 * * *", arg_name="timer", run_on_startup=True)  # Runs every 1 hour
def fetch_data(timer: func.TimerRequest):
    logging.info("Starting data fetch process...")
    first_run = is_first_run()
    jira_tickets = fetch_jira_tickets(first_run)
    confluence_pages = fetch_confluence_pages(first_run)
    store_data_in_cosmosdb(jira_tickets + confluence_pages)
    logging.info("Data fetch completed successfully.")
    return func.HttpResponse("Data successfully fetched and stored.", status_code=200)

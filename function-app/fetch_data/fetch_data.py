import os
import json
import requests
import azure.functions as func
import logging
from azure.cosmos import CosmosClient
from datetime import datetime, timedelta
from azure.ai.vision.imageanalysis import ImageAnalysisClient
print(dir(ImageAnalysisClient))
from azure.ai.documentintelligence import DocumentIntelligenceClient
from azure.core.credentials import AzureKeyCredential  # Add this import
from dotenv import load_dotenv
from requests.auth import HTTPBasicAuth
load_dotenv()  # This loads the .env file
print("JIRA_API_URL:", os.getenv("JIRA_API_URL"))


# Environment Variables
JIRA_API_URL = os.getenv("JIRA_API_URL")
JIRA_USERNAME = os.getenv("JIRA_API_USERNAME")
JIRA_API_TOKEN = os.getenv("JIRA_API_TOKEN")
CONFLUENCE_API_URL = os.getenv("CONFLUENCE_API_URL")
CONFLUENCE_USERNAME = os.getenv("CONFLUENCE_API_USERNAME")
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
vision_client = ImageAnalysisClient(endpoint=AZURE_VISION_ENDPOINT, credential=AzureKeyCredential(AZURE_VISION_KEY) )
document_intelligence_client = DocumentIntelligenceClient(endpoint=AZURE_DOCUMENT_INTELLIGENCE_ENDPOINT, credential=AzureKeyCredential(AZURE_DOCUMENT_INTELLIGENCE_KEY))

# Function to check if this is the first run
def is_first_run():
    logging.info("Checking if this is the first data fetch...")
    return container.query_items(query="SELECT VALUE COUNT(1) FROM c", enable_cross_partition_query=True).__next__() == 0
    logging.info(f"is_first_run() returned: {is_first_run()}")


# Function to analyze images using Azure AI Vision
def analyze_image(image_url, base_url=None):
    # If the URL does not start with "http", it is relative.
    if not image_url.startswith("http"):
        if base_url:
            # Prepend the base_url to form an absolute URL.
            image_url = base_url.rstrip("/") + "/" + image_url.lstrip("/")
        else:
            logging.error("Relative image URL provided but no base_url given.")
            return None

    logging.info(f"Processing image: {image_url}")
    
    # Fetch the image using credentials (this works for both Jira and Confluence if the URL is absolute)
    image_response = requests.get(image_url, auth=HTTPBasicAuth(JIRA_USERNAME, JIRA_API_TOKEN))
    if image_response.status_code != 200:
        logging.error(f"Failed to fetch image from URL: {image_url} - Status code: {image_response.status_code}")
        return None
    image_data = image_response.content
    
    # Analyze the image using the Vision client
    try:
        analysis_response = vision_client.analyze(image_data, visual_features=["Tags"])
    except Exception as e:
        logging.error(f"Vision analysis failed: {str(e)}")
        return None

    logging.info(f"Vision client response: {analysis_response}")
    
    if analysis_response:
        logging.info("Image processed successfully")
        tags = []
        if "tagsResult" in analysis_response and "values" in analysis_response["tagsResult"]:
            tags = [tag["name"] for tag in analysis_response["tagsResult"]["values"]]
        return tags
    
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
    #headers = {"Authorization": f"Basic {JIRA_API_TOKEN}", "Content-Type": "application/json"}
    auth = HTTPBasicAuth(JIRA_USERNAME, JIRA_API_TOKEN)
    jql_query = "ORDER BY created DESC" if first_run else f"updated >= '{(datetime.utcnow() - timedelta(days=1)).strftime('%Y-%m-%d')}'"
    response = requests.get(f"{JIRA_API_URL}/search?jql={jql_query}&fields=summary,description,attachment", auth=auth)
    logging.info(f"Jira response status: {response.status_code}")
    logging.info(f"Jira response body: {response.text}")

    #response = requests.get(f"{JIRA_API_URL}/search?jql={jql_query}&fields=summary,description,attachment", headers=headers)

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
    logging.error(f"Failed to fetch Jira tickets: {response.status_code} {response.text}")
    return []

# Function to fetch Confluence pages including image & document analysis
def fetch_confluence_pages(first_run=False):
    logging.info("Fetching Confluence pages...")
    #headers = {"Authorization": f"Basic {CONFLUENCE_API_TOKEN}", "Content-Type": "application/json"}
    #response = requests.get(
    #    f"{CONFLUENCE_API_URL}/rest/api/content?type=page&expand=version,metadata.labels,body.storage,children.attachment",
    #    headers=headers
    #)
    auth = HTTPBasicAuth(CONFLUENCE_USERNAME, CONFLUENCE_API_TOKEN)
    response = requests.get(
        f"{CONFLUENCE_API_URL}/rest/api/content?type=page&expand=version,metadata.labels,body.storage,children.attachment",
        auth=auth
    )

    if response.status_code == 200:
        pages = response.json().get("results", [])
        for page in pages:
            attachments = page.get("children", {}).get("attachment", {}).get("results", [])
            for att in attachments:
                if att["metadata"]["mediaType"].startswith("image/"):
                    extracted_text = analyze_image(att["_links"]["download"], base_url=CONFLUENCE_API_URL)
                    page["image_text"] = extracted_text if extracted_text else "No text extracted."
                elif att["metadata"]["mediaType"].startswith("application/pdf"):
                    extracted_pdf_text = analyze_pdf(att["_links"]["download"])
                    page["pdf_text"] = extracted_pdf_text if extracted_pdf_text else "No structured data extracted."

        logging.info(f"Fetched {len(pages)} Confluence pages")
        return pages
    logging.error(f"Failed to fetch Confluence pages: {response.status_code} {response.text}")
    return []

# Function to store data in CosmosDB
def store_data_in_cosmosdb(data):
    logging.info("Storing data in CosmosDB...")
    for record in data:
        try:
            container.upsert_item(record)
        except Exception as e:
            logging.error(f"Error inserting record: {str(e)}")


#for tmer triggered function
#app = func.FunctionApp()

#@app.function_name("fetch_data")
#@app.schedule(schedule="0 */1 * * *", arg_name="timer", run_on_startup=True)  # Runs every 1 hour
#def fetch_data(timer: func.TimerRequest):
#    logging.info("Starting data fetch process...")
#    first_run = is_first_run()
#    jira_tickets = fetch_jira_tickets(first_run)
#    confluence_pages = fetch_confluence_pages(first_run)
#    store_data_in_cosmosdb(jira_tickets + confluence_pages)
#    logging.info("Data fetch completed successfully.")
#    return func.HttpResponse("Data successfully fetched and stored.", status_code=200)

# for http triggered function
#@app.function_name("fetch_data")
#@app.route(route="fetch_data", auth_level=func.AuthLevel.FUNCTION)
#def fetch_data(req: func.HttpRequest) -> func.HttpResponse:
#    logging.info("HTTP function fetch_data executed successfully.")#

#    first_run = is_first_run()
#    jira_tickets = fetch_jira_tickets(first_run)
#    confluence_pages = fetch_confluence_pages(first_run)#

#    #  Debug: Print Jira & Confluence Data
#    print(f"Fetched {len(jira_tickets)} Jira tickets")
#    print(json.dumps(jira_tickets, indent=2))  # Print Jira data
#    print(f"Fetched {len(confluence_pages)} Confluence pages")
#    print(json.dumps(confluence_pages, indent=2))  # Print Confluence data#

#    store_data_in_cosmosdb(jira_tickets + confluence_pages)
#    logging.info("Data fetch completed successfully.") 
#    return func.HttpResponse("Data successfully fetched and stored.", status_code=200)

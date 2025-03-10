import os
import json
import logging
from datetime import datetime, timedelta
from dotenv import load_dotenv

# Import your core functions from fetch_data.py
from fetch_data import is_first_run, fetch_jira_tickets, fetch_confluence_pages, store_data_in_cosmosdb

# Load environment variables from .env file
load_dotenv()

# Set up logging
logging.basicConfig(level=logging.INFO)

def main():
    logging.info("Local script started.")

    # For testing, you can force a first run (so your query returns more data)
    first_run = True  # Alternatively: first_run = is_first_run()

    # Fetch data from Jira and Confluence
    jira_tickets = fetch_jira_tickets(first_run)
    confluence_pages = fetch_confluence_pages(first_run)

    # Log and print fetched data counts
    logging.info(f"Fetched {len(jira_tickets)} Jira tickets")
    logging.info(f"Fetched {len(confluence_pages)} Confluence pages")
    print("Jira Tickets:", json.dumps(jira_tickets, indent=2))
    print("Confluence Pages:", json.dumps(confluence_pages, indent=2))

    # Store data in CosmosDB
    store_data_in_cosmosdb(jira_tickets + confluence_pages)
    logging.info("Data successfully inserted into CosmosDB.")

if __name__ == '__main__':
    main()

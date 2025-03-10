import os
import sys
sys.path.insert(0, os.path.dirname(__file__))
import logging
import azure.functions as func
from .fetch_data import is_first_run, fetch_jira_tickets, fetch_confluence_pages, store_data_in_cosmosdb

def main(timer: func.TimerRequest) -> None:
    logging.info("Timer triggered function started.")
    first_run = is_first_run()
    jira_tickets = fetch_jira_tickets(first_run)
    confluence_pages = fetch_confluence_pages(first_run)
    store_data_in_cosmosdb(jira_tickets + confluence_pages)
    logging.info("Timer triggered function completed.")

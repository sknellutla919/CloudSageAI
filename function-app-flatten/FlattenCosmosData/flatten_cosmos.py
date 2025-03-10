import os
import logging
import azure.functions as func
from azure.cosmos import CosmosClient

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

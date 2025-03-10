import logging
import azure.functions as func
from .flatten_cosmos import main as flatten_cosmos_main

def main(timer: func.TimerRequest) -> None:
    logging.info("Timer triggered flatten cosmos function started.")
    flatten_cosmos_main(timer)
    logging.info("Timer triggered flatten cosmos function completed.")




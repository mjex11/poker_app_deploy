import os
import json
import logging
import requests

# Set up logging
logger = logging.getLogger('lambda_logger')
logger.setLevel(logging.INFO)

def lambda_handler(event, context):
    # Error handling for missing imageTag
    try:
        image_tag = event['detail']['image-tag']
    except KeyError:
        logger.error("Missing imageTag in event data.")
        raise

    owner = os.getenv('GITHUB_OWNER')
    repo  = os.getenv('GITHUB_REPO')
    token = os.getenv('GITHUB_TOKEN')

    headers = {
        'Accept': 'application/vnd.github.everest-preview+json',
        'Authorization': f'token {token}',
    }

    data = {
        'event_type': 'ECR Push',
        'client_payload': {
            'image_tag': image_tag
        }
    }

    # Error handling for the POST request
    try:
        response = requests.post(f'https://api.github.com/repos/{owner}/{repo}/dispatches', headers=headers, data=json.dumps(data))
        response.raise_for_status()
    except requests.exceptions.RequestException as e:
        logger.error(f"Failed to send POST request: {e}")
        raise

    logger.info("Successfully triggered GitHub Actions workflow.")
    
    return {
        'statusCode': 200,
        'body': json.dumps('Success!')
    }

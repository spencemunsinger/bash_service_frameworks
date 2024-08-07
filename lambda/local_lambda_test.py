import json
import run_script

if __name__ == "__main__":
    # Simulate an event JSON file
    with open('event.json', 'r') as f:
        event = json.load(f)
    context = {}  # You can simulate AWS Lambda context here if needed
    run_script.lambda_handler(event, context)

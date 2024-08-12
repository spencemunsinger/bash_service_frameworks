#!/usr/bin/env bash

# Function to handle the Lambda event
handle_lambda_event() {
    # Read input from standard input
    input=$(cat -)

    # Extract values from the input JSON (example assumes 'name' key)
    name=$(echo "$input" | jq -r '.name')

    # Perform some action with the input (example: greeting message)
    response=$(jq -n --arg message "Hello, $name" '{message: $message}')

    # Output the response as JSON
    echo "$response"
}

# Check if running as a Lambda container
if [ "$AWS_LAMBDA_RUNTIME_API" ]; then
    handle_lambda_event
else
    echo
    echo "MAIN: reached main script $0"
    echo "MAIN: local content: $(ls -la)"
    echo "MAIN: args submitted: $@"
    echo
fi

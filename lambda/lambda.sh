#!/usr/bin/env bash

# Function to handle the Lambda event
handle_lambda_event() {
    # Determine if running in AWS Lambda environment
    if [ -n "$AWS_LAMBDA_FUNCTION_NAME" ]; then
        # Read input from standard input (Lambda payload)
        input=$(cat -)

        # Extract arguments from the input JSON
        args=$(echo "$input" | jq -r '.args | join(" ")')

        # Execute the main script with extracted arguments
        bash ./main.sh $args
    else
        # If not in Lambda, read arguments from stdin
        args="$@"

        # Execute the main script with provided arguments
        bash ./main.sh $args
    fi
}

# Invoke the handler
handle_lambda_event "$@"

#!/usr/bin/env bash

# Function to check if curl is installed
check_curl_installed() {
    if ! command -v curl &> /dev/null; then
        echo "curl could not be found. Please install curl and try again."
        exit 1
    fi
}

# Verify jq is installed
check_jq_installed() {
    if ! command -v jq &> /dev/null; then
        echo "jq could not be found. Please install jq and try again."
        exit 1
    fi
}

# Function to display usage
usage() {
    echo "Usage: $0 [-a] [-c] [-e environment] [-f] [-p] [-s] [-t]"
    exit 1
}

# Function to display a "." every second
show_progress() {
    while true; do
        echo -n "."
        sleep 1
    done
}

# Check if curl and jq are installed
check_curl_installed
check_jq_installed

# Initialize an empty array to hold the arguments
ARGS=()

# Parse the input arguments
while getopts ":ace:fpsth" opt; do
    case ${opt} in
        a )
            ARGS+=("-a")
            ;;
        c )
            ARGS+=("-c")
            ;;
        e )
            ARGS+=("-e" "${OPTARG}")
            ;;
        f )
            ARGS+=("-f")
            ;;
        p )
            ARGS+=("-p")
            ;;
        s )
            ARGS+=("-s")
            ;;
        t )
            ARGS+=("-t")
            ;;
        h )
            usage
            ;;
        \? )
            echo "Invalid option: $OPTARG" 1>&2
            usage
            ;;
        : )
            echo "Invalid option: $OPTARG requires an argument" 1>&2
            usage
            ;;
    esac
done

# Convert ARGS array to JSON array string
JSON_ARGS=$(printf '%s\n' "${ARGS[@]}" | jq -R . | jq -s .)

echo 
echo "  calling service with arguments: ${ARGS[@]}"
echo 

# Start the progress indicator in the background
echo -n "  start: " 
show_progress &
PROGRESS_PID=$!

# Make the curl call silently and process the output with jq
curl_output=$(curl -s -X POST http://localhost:8080/run-script -H "Content-Type: application/json" -d "{\"args\": $JSON_ARGS}")

# Kill the progress indicator
kill $PROGRESS_PID
echo " :complete"

# Print a newline after progress dots
echo
echo "  service response: "
echo 
echo "  _____________________________________________________________"

# Process the curl output with jq
echo "$curl_output" | jq .

echo "  _____________________________________________________________"
echo

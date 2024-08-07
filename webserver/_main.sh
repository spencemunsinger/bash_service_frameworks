#!/usr/bin/env bash

# echo "Running _main.sh with arguments: $@"

# echo "running at $(pwd)"

# # Exit with a success status
# echo "Script execution completed successfully"
# exit 0

echo "Running _main.sh with arguments: $@"

# Add your script logic here
# Example logic to demonstrate script execution
for arg in "$@"
do
    echo "Processing argument: $arg"
done

echo "_main.sh script execution completed."

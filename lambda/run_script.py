import os
import subprocess
import json

def lambda_handler(event, context):
    # Extract arguments from the event
    arg1 = event.get('arg1', 'default_value1')
    arg2 = event.get('arg2', 'default_value2')

    # Set environment variables for the script
    os.environ['ARG1'] = arg1
    os.environ['ARG2'] = arg2

    # Construct the command to run the script with arguments
    command = ['/usr/local/bin/chase/_main.sh', arg1, arg2]

    try:
        # Execute the script
        result = subprocess.run(command, capture_output=True, text=True)
        return {
            'statusCode': 200,
            'body': json.dumps({
                'stdout': result.stdout,
                'stderr': result.stderr,
                'returncode': result.returncode
            })
        }
    except Exception as e:
        return {
            'statusCode': 500,
            'body': str(e)
        }

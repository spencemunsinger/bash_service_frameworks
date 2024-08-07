import os
import sys
import json
import subprocess
import argparse

def run_main_script(args):
    print(f"Running _main.sh with arguments: {args}")
    # Call the bash script with the provided arguments
    result = subprocess.run(["/bin/bash", "/usr/local/bin/chase/_main.sh"] + args, capture_output=True, text=True)
    print(f"Script stdout:\n{result.stdout}")
    print(f"Script stderr:\n{result.stderr}", file=sys.stderr)
    return result.returncode

def main():
    if os.getenv('AWS_LAMBDA_FUNCTION_NAME'):
        print("Running inside AWS Lambda")
        # Running inside AWS Lambda
        event_file_path = '/var/task/event.json'
        if os.path.exists(event_file_path):
            try:
                with open(event_file_path, 'r') as f:
                    event = json.load(f)
                    args = event.get('args', [])
                    return run_main_script(args)
            except Exception as e:
                print(f"Error reading or parsing event.json: {e}", file=sys.stderr)
                return 1
        else:
            print(f"{event_file_path} not found", file=sys.stderr)
            return 1
    else:
        print("Running on command line")
        # Running on command line
        parser = argparse.ArgumentParser(description='Run _main.sh with arguments')
        parser.add_argument('args', nargs=argparse.REMAINDER, help='Arguments to pass to _main.sh')
        parsed_args = parser.parse_args()
        return run_main_script(parsed_args.args)

if __name__ == '__main__':
    exit_code = main()
    sys.exit(exit_code)

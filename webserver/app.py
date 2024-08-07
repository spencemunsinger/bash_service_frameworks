from flask import Flask, request, jsonify
import subprocess

app = Flask(__name__)

@app.route('/run-script', methods=['POST'])
def run_script():
    # Get the arguments from the POST request
    args = request.json.get('args')
    if not args:
        return jsonify({"error": "No arguments provided"}), 400

    # Build the command to run the bash script
    cmd = ['/app/_main.sh'] + args

    try:
        # Execute the bash script and capture the output
        result = subprocess.run(cmd, check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        output = result.stdout.decode('utf-8')
        error = result.stderr.decode('utf-8')
        return jsonify({"output": output, "error": error})
    except subprocess.CalledProcessError as e:
        return jsonify({"error": str(e), "output": e.output.decode('utf-8'), "stderr": e.stderr.decode('utf-8')}), 500

if __name__ == '__main__':
    app.run(host='0.0.0.0', port=8080)

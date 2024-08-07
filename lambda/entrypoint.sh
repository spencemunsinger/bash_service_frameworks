#!/usr/bin/env sh

cd /usr/local/bin/chase-h2h-key-rotate

# Check if running as a Lambda container
if [ "$AWS_LAMBDA_RUNTIME_API" ]; then
    exec /opt/venv/bin/python3 -m awslambdaric lambda.sh "$@"
else
    exec ./lambda.sh "$@"
fi

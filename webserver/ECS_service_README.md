# ECS Service

---

## terraform (proposed)


```hcl

provider "aws" {
  region = "us-east-1"
}

data "aws_caller_identity" "current" {}

# IAM Role for ECS Task
resource "aws_iam_role" "ecs_task_execution_role" {
  name = "ecs-task-execution-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "ecs-tasks.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

# Attach Policies to ECS Task Execution Role
resource "aws_iam_role_policy_attachment" "ecs_task_execution_policy" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AmazonECSTaskExecutionRolePolicy"
}

resource "aws_iam_policy_document" "ecs_secretsmanager_policy_doc" {
  statement {
    actions = [
      "secretsmanager:GetSecretValue",
      "secretsmanager:PutSecretValue",
      "secretsmanager:UpdateSecretVersionStage"
    ]
    resources = [
      "arn:aws:secretsmanager:us-east-1:${data.aws_caller_identity.current.account_id}:secret:${var.toast_env}/rsaKey/*"
    ]
  }
}

resource "aws_iam_policy" "ecs_secretsmanager_policy" {
  name   = "ecs-secretsmanager-policy"
  policy = data.aws_iam_policy_document.ecs_secretsmanager_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "ecs_secretsmanager_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_secretsmanager_policy.arn
}

resource "aws_iam_policy_document" "ecs_kms_policy_doc" {
  statement {
    actions = ["kms:Decrypt"]
    resources = ["${var.kms_key_arn}"]
  }
}

resource "aws_iam_policy" "ecs_kms_policy" {
  name   = "ecs-kms-policy"
  policy = data.aws_iam_policy_document.ecs_kms_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "ecs_kms_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_kms_policy.arn
}

resource "aws_iam_policy_document" "ecs_sts_policy_doc" {
  statement {
    actions   = ["sts:GetCallerIdentity"]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "ecs_sts_policy" {
  name   = "ecs-sts-policy"
  policy = data.aws_iam_policy_document.ecs_sts_policy_doc.json
}

resource "aws_iam_role_policy_attachment" "ecs_sts_policy_attachment" {
  role       = aws_iam_role.ecs_task_execution_role.name
  policy_arn = aws_iam_policy.ecs_sts_policy.arn
}

# ECS Cluster
resource "aws_ecs_cluster" "ecs_cluster" {
  name = "ecs-cluster"
}

# ECS Task Definition
resource "aws_ecs_task_definition" "ecs_task_definition" {
  family                   = "ecs-task-family"
  network_mode             = "awsvpc"
  requires_compatibilities = ["FARGATE"]
  cpu                      = "512"
  memory                   = "1024"
  execution_role_arn       = aws_iam_role.ecs_task_execution_role.arn
  task_role_arn            = aws_iam_role.ecs_task_execution_role.arn

  container_definitions = jsonencode([
    {
      name      = "flask-app"
      image     = "${data.aws_caller_identity.current.account_id}.dkr.ecr.us-east-1.amazonaws.com/toast/toast-chase-test-ecs-docker:${var.image_tag}"
      essential = true
      portMappings = [
        {
          containerPort = 8443
          hostPort      = 8443
          protocol      = "tcp"
        }
      ]
    }
  ])
}

# ECS Service
resource "aws_ecs_service" "ecs_service" {
  name            = "ecs-service"
  cluster         = aws_ecs_cluster.ecs_cluster.id
  task_definition = aws_ecs_task_definition.ecs_task_definition.arn
  desired_count   = 1
  launch_type     = "FARGATE"

  network_configuration {
    subnets          = ["subnet-07114bdf5fdd4595e"]
    security_groups  = [aws_security_group.ecs_service_sg.id]
    assign_public_ip = true
  }
}

# Security Group for ECS Service
resource "aws_security_group" "ecs_service_sg" {
  name        = "ecs-service-sg"
  description = "Security group for ECS service"
  vpc_id      = data.aws_vpc.aws_backspace_test.id

  ingress {
    from_port   = 8443
    to_port     = 8443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# API Gateway
resource "aws_api_gateway_rest_api" "api_gateway" {
  name        = "ecs-service-api"
  description = "API Gateway for ECS service"
}

resource "aws_api_gateway_resource" "ecs_service_resource" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  parent_id   = aws_api_gateway_rest_api.api_gateway.root_resource_id
  path_part   = "service"
}

resource "aws_api_gateway_method" "ecs_service_method" {
  rest_api_id   = aws_api_gateway_rest_api.api_gateway.id
  resource_id   = aws_api_gateway_resource.ecs_service_resource.id
  http_method   = "PUT"
  authorization = "AWS_IAM"
}

resource "aws_api_gateway_integration" "ecs_service_integration" {
  rest_api_id             = aws_api_gateway_rest_api.api_gateway.id
  resource_id             = aws_api_gateway_resource.ecs_service_resource.id
  http_method             = aws_api_gateway_method.ecs_service_method.http_method
  integration_http_method = "PUT"
  type                    = "HTTP_PROXY"
  uri                     = "http://${aws_ecs_service.ecs_service.network_configuration.0.assign_public_ip}/service"
}

resource "aws_api_gateway_deployment" "ecs_service_deployment" {
  rest_api_id = aws_api_gateway_rest_api.api_gateway.id
  stage_name  = "prod"

  depends_on = [
    aws_api_gateway_integration.ecs_service_integration,
    aws_api_gateway_method.ecs_service_method
  ]
}

# IAM Role for API Gateway
resource "aws_iam_role" "api_gateway_role" {
  name = "api-gateway-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Principal = {
          Service = "apigateway.amazonaws.com"
        },
        Action = "sts:AssumeRole"
      }
    ]
  })
}

resource "aws_iam_policy" "api_gateway_policy" {
  name   = "api-gateway-policy"
  policy = jsonencode({
    Version = "2012-10-17",
    Statement = [
      {
        Effect = "Allow",
        Action = "execute-api:Invoke",
        Resource = "*"
      }
    ]
  })
}

resource "aws_iam_role_policy_attachment" "api_gateway_policy_attachment" {
  role       = aws_iam_role.api_gateway_role.name
  policy_arn = aws_iam_policy.api_gateway_policy.arn
}


```


---

## API gateway and auth


To authenticate access to the API Gateway and use the provided bash script, the process involves several steps:

### Authentication with API Gateway
API Gateway can be configured to use IAM roles for authentication. This means that users must authenticate using AWS credentials (either temporary credentials from AWS STS or long-term IAM user credentials) to gain access to the API.

### Steps for a User to Authenticate and Use the Script

1. **Install AWS CLI**: Ensure the AWS CLI is installed on your local machine. You can install it from [here](https://aws.amazon.com/cli/).

2. **Configure AWS CLI**: Configure the AWS CLI with your IAM user credentials or assume an IAM role that has the necessary permissions to invoke the API Gateway endpoint.
   ```bash
   aws configure
   ```

3. **Obtain Temporary Credentials** (if using assumed roles): Use the AWS CLI to assume a role and obtain temporary credentials.
   ```bash
   aws sts assume-role --role-arn arn:aws:iam::ACCOUNT_ID:role/ROLE_NAME --role-session-name SESSION_NAME
   ```

4. **Modify the Script to Include AWS Signature**: The bash script needs to include AWS Signature V4 to sign the requests to the API Gateway. Here's how to modify the script to include this:

### Modified Bash Script with AWS Signature

```bash
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

# Get AWS credentials from environment or AWS CLI config
AWS_ACCESS_KEY_ID=$(aws configure get aws_access_key_id)
AWS_SECRET_ACCESS_KEY=$(aws configure get aws_secret_access_key)
AWS_SESSION_TOKEN=$(aws configure get aws_session_token)  # Needed if using temporary credentials

# Function to generate AWS Signature V4
generate_aws_signature() {
    local method=$1
    local service=$2
    local host=$3
    local region=$4
    local endpoint=$5
    local request_parameters=$6

    local now=$(date -u +"%Y%m%dT%H%M%SZ")
    local date_stamp=$(date -u +"%Y%m%d")

    local canonical_uri="/run-script"
    local canonical_querystring=""
    local canonical_headers="content-type:application/json\nhost:${host}\nx-amz-date:${now}\n"
    local signed_headers="content-type;host;x-amz-date"

    local payload_hash=$(echo -n "${request_parameters}" | openssl dgst -sha256 | sed 's/^.* //')
    local canonical_request="${method}\n${canonical_uri}\n${canonical_querystring}\n${canonical_headers}\n${signed_headers}\n${payload_hash}"

    local algorithm="AWS4-HMAC-SHA256"
    local credential_scope="${date_stamp}/${region}/${service}/aws4_request"
    local string_to_sign="${algorithm}\n${now}\n${credential_scope}\n$(echo -n "${canonical_request}" | openssl dgst -sha256 | sed 's/^.* //')"

    local k_date=$(echo -n "${date_stamp}" | openssl dgst -sha256 -hmac "AWS4${AWS_SECRET_ACCESS_KEY}" | sed 's/^.* //')
    local k_region=$(echo -n "${region}" | openssl dgst -sha256 -hmac "${k_date}" | sed 's/^.* //')
    local k_service=$(echo -n "${service}" | openssl dgst -sha256 -hmac "${k_region}" | sed 's/^.* //')
    local k_signing=$(echo -n "aws4_request" | openssl dgst -sha256 -hmac "${k_service}" | sed 's/^.* //')

    local signature=$(echo -n "${string_to_sign}" | openssl dgst -sha256 -hmac "${k_signing}" | sed 's/^.* //')

    local authorization_header="${algorithm} Credential=${AWS_ACCESS_KEY_ID}/${credential_scope}, SignedHeaders=${signed_headers}, Signature=${signature}"

    echo "${authorization_header}"
}

# AWS Signature V4 parameters
METHOD="POST"
SERVICE="execute-api"
HOST="your-api-id.execute-api.us-east-1.amazonaws.com"
REGION="us-east-1"
ENDPOINT="https://${HOST}/prod/service"
REQUEST_PARAMETERS="{\"args\": $JSON_ARGS}"

# Generate AWS Signature
AUTHORIZATION_HEADER=$(generate_aws_signature "$METHOD" "$SERVICE" "$HOST" "$REGION" "$ENDPOINT" "$REQUEST_PARAMETERS")

# Make the curl call silently and process the output with jq
curl_output=$(curl -s -X POST "${ENDPOINT}" -H "Content-Type: application/json" -H "Authorization: ${AUTHORIZATION_HEADER}" -H "x-amz-date: $(date -u +"%Y%m%dT%H%M%SZ")" -H "x-amz-security-token: ${AWS_SESSION_TOKEN}" -d "{\"args\": $JSON_ARGS}")

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
```

### Explanation:
1. **IAM Role for API Gateway**: The API Gateway uses an IAM role to validate the requester's permissions. The `aws_iam_role` and `aws_iam_role_policy_attachment` resources create and attach the necessary policies to the role.

2. **AWS Signature V4**: The script includes a function to generate the AWS Signature V4, which is used to sign the request to the API Gateway.

3. **AWS Credentials**: The script retrieves AWS credentials from the AWS CLI configuration. For temporary credentials (e.g., when assuming a role), it also retrieves the session token.

4. **Progress Indicator**: The script includes a progress indicator that runs in the background while the curl command executes.

5. **cURL Command**: The curl command includes the necessary headers for AWS Signature V4 authentication, including the Authorization header, x-amz-date, and x-amz-security-token.

This setup ensures that the API Gateway only allows authenticated requests from users with the correct IAM permissions. The script handles the authentication process and demonstrates how to interact with the secure API.
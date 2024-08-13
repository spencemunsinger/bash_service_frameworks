## VPC & NETWORKING (playground testing only)

resource "aws_vpc" "main" {
  count             = var.toast_env == "playground" ? 1 : 0
  cidr_block       = "10.4.0.0/16"
  instance_tenancy = "default"
  enable_dns_support = true
  enable_dns_hostnames = true
  tags = {
    Name               = "aws-backspace-test"
    toast_environment  = "${var.toast_env}"
    toast_service_name = "aws-backspace"
  }
}

resource "aws_internet_gateway" "main" {
  count             = var.toast_env == "playground" ? 1 : 0
  vpc_id = aws_vpc.main[count.index].id
  tags = {
    Name               = "aws-backspace-test"
    toast_environment  = "${var.toast_env}"
    toast_service_name = "aws-backspace"
  }
}

resource "aws_subnet" "az1-outside" {
  count             = var.toast_env == "playground" ? 1 : 0
  vpc_id                  = aws_vpc.main[count.index].id
  cidr_block              = "10.4.0.0/24"
  availability_zone       = "us-east-1a"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.toast_env}-az1-subnet-outside"
    toast_environment  = "${var.toast_env}"
    toast_service_name = "aws-backspace"
  }
}

resource "aws_subnet" "az2-outside" {
  count             = var.toast_env == "playground" ? 1 : 0
  vpc_id                  = aws_vpc.main[count.index].id
  cidr_block              = "10.4.1.0/24"
  availability_zone       = "us-east-1b"
  map_public_ip_on_launch = true
  tags = {
    Name = "${var.toast_env}-az2-subnet-outside"
    toast_environment  = "${var.toast_env}"
    toast_service_name = "aws-backspace"
  }
}

resource "aws_route_table" "outside" {
  count             = var.toast_env == "playground" ? 1 : 0
  vpc_id = aws_vpc.main[count.index].id
  tags = {
    Name = "${var.toast_env}-outside"
    toast_environment  = "${var.toast_env}"
    toast_service_name = "aws-backspace"
  }
}

resource "aws_route" "outside" {
  count             = var.toast_env == "playground" ? 1 : 0
  route_table_id         = aws_route_table.outside[count.index].id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.main[count.index].id
}

resource "aws_route_table_association" "outside-az1" {
  count             = var.toast_env == "playground" ? 1 : 0
  subnet_id      = aws_subnet.az1-outside[count.index].id
  route_table_id = aws_route_table.outside[count.index].id
}

resource "aws_route_table_association" "outside-az2" {
  count             = var.toast_env == "playground" ? 1 : 0
  subnet_id      = aws_subnet.az2-outside[count.index].id
  route_table_id = aws_route_table.outside[count.index].id
}

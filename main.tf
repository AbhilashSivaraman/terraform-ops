terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket       = "terra-bucket-816069140701"
    key          = "ec2/terraform.tfstate"
    region       = "ap-south-1"
    use_lockfile = true
  }
}

provider "aws" {
  region = "ap-south-1"
}

# Default VPC
data "aws_vpc" "default" {
  default = true
}

# Subnets in default VPC
data "aws_subnets" "default" {
  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default.id]
  }
}

# Latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

# Security group
resource "aws_security_group" "ec2" {
  name   = "terraform-ec2-sg"
  vpc_id = data.aws_vpc.default.id

  # Allow SSH access
  ingress {
    description = "SSH access"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow outbound traffic
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# EC2 instance
resource "aws_instance" "example" {
  ami           = data.aws_ami.amazon_linux.id
  instance_type = "t3.micro"
  subnet_id     = data.aws_subnets.default.ids[0]

  # Existing AWS key pair
  key_name = "WebTwoKey"

  # Attach security group
  vpc_security_group_ids = [
    aws_security_group.ec2.id
  ]

  # Root EBS volume: 10 GB gp3
  root_block_device {
    volume_size = 33
    volume_type = "gp3"
  }

  tags = {
    Name = "terraform-ec2"
  }
}

# Output instance ID
output "instance_id" {
  description = "EC2 instance ID"
  value       = aws_instance.example.id
}

# Output public IP
output "public_ip" {
  description = "EC2 public IP address"
  value       = aws_instance.example.public_ip
}

# Output SSH command
output "ssh_command" {
  description = "SSH command template"
  value       = "ssh -i WebTwoKey.pem ec2-user@${aws_instance.example.public_ip}"
}
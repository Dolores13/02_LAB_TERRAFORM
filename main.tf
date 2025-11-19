terraform {
  required_version = ">= 1.6.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.95.0, < 6.0.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = "~> 2.32"
    }
  }
}


# Variables

variable "region" {
  description = "AWS region"
  type        = string
  default     = "us-east-1"
}

variable "access_key" {
  description = "AWS Access Key"
  type        = string
  sensitive   = true
}

variable "secret_key" {
  description = "AWS Secret Key"
  type        = string
  sensitive   = true
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}


variable "ami_id" {
  description = "Ubuntu 22.04 AMI in region"
  type        = string
  default     = "ami-054d6a336762e438e"
}

locals {
  project   = "lab2-terraform"
  extra_tag = "extra-tag"
}


# Providers

provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}

# VPC (2 zones , 2 public, 2 private)

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"
 

  name = "${local.project}-vpc"
  cidr = "10.0.0.0/16"

  azs              = ["${var.region}a", "${var.region}b"]
  public_subnets   = ["10.0.1.0/24", "10.0.2.0/24"]
  private_subnets  = ["10.0.10.0/24", "10.0.20.0/24"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Project     = local.project
    Environment = "dev"
  }
   public_subnet_tags = {
    "kubernetes.io/cluster/${local.project}-eks" = "shared"
    "kubernetes.io/role/elb"                     = "1"
  }

  private_subnet_tags = {
    "kubernetes.io/cluster/${local.project}-eks" = "shared"
    "kubernetes.io/role/internal-elb"            = "1"
  }
}

# Security Group: 22,80
resource "aws_security_group" "web_sg" {
  name        = "${local.project}-web-sg"
  description = "Allow SSH and HTTP"
  vpc_id      = module.vpc.vpc_id

  ingress {
    description = "SSH"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name     = "${local.project}-web-sg"
    extraTag = local.extra_tag
  }
}
# EC2 with Nginx
resource "aws_instance" "web" {
  count                       = length(module.vpc.public_subnets)
  ami                         = var.ami_id
  instance_type               = var.instance_type
  subnet_id                   = module.vpc.public_subnets[count.index]
  vpc_security_group_ids      = [aws_security_group.web_sg.id]
  associate_public_ip_address = true

  user_data = <<-EOF
#!/bin/bash
set -eux
apt-get update -y
apt-get install -y nginx
echo '<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Lab 2</title>
  <meta name="viewport" content="width=device-width, initial-scale=1" />
  <style>
    body { font-family: Arial, sans-serif; margin: 0; background:#f7f7fb; color:#222; }
    main { max-width: 700px; margin: 10vh auto; background:#fff; padding: 2rem;
           border-radius: 12px; box-shadow: 0 10px 30px rgba(0,0,0,.06); text-align:center; }
    h1 { margin-top: 0; }
    button { padding: .8rem 1.2rem; border: none; border-radius: 10px; cursor: pointer;
             background: #222; color: #fff; font-weight: 700; }
    button:hover { opacity: .9; }
    .small { color:#666; font-size:.95rem; }
  </style>
</head>
<body>
  <main>
    <h1>This is Lab 2 where I learned Terraform! Thanks.</h1>
    <p class="small">Instance: EC2 >>${count.index + 1}<< (public subnet)</p>
    <button onclick="liked()">Press if you liked it</button>
  </main>
  <script>
    function liked(){ alert("Thank you very much!"); }
  </script>
</body>
</html>' | tee /var/www/html/index.html
systemctl enable nginx
systemctl restart nginx
EOF

  tags = {
    Name     = "${local.project}-web-${count.index + 1}"
    extraTag = local.extra_tag
  }
}
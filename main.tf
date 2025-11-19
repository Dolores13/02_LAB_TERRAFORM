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


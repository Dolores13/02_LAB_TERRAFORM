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


# Providers

provider "aws" {
  region     = var.region
  access_key = var.access_key
  secret_key = var.secret_key
}


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

# Application Load Balancer (ALB)

resource "aws_lb" "alb" {
  name               = "${local.project}-alb"
  load_balancer_type = "application"
  internal           = false
  subnets            = module.vpc.public_subnets
  security_groups    = [aws_security_group.web_sg.id]

  tags = {
    Name     = "${local.project}-alb"
    extraTag = local.extra_tag
  }
}

resource "aws_lb_target_group" "tg" {
  name     = "${local.project}-tg"
  port     = 80
  protocol = "HTTP"
  vpc_id   = module.vpc.vpc_id
  health_check {
    path                = "/"
    matcher             = "200-399"
    healthy_threshold   = 2
    unhealthy_threshold = 2
    timeout             = 5
    interval            = 15
  }
  tags = {
    Name = "${local.project}-tg"
  }
}

# Attach instances to target group
resource "aws_lb_target_group_attachment" "att" {
  for_each         = { for idx, id in aws_instance.web[*].id : idx => id }
  target_group_arn = aws_lb_target_group.tg.arn
  target_id        = each.value
  port             = 80
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# EKS: single cluster 

module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.0"

  cluster_name    = "${local.project}-eks"
  cluster_version = "1.29"
  enable_irsa     = true

  cluster_endpoint_public_access  = true
  cluster_endpoint_private_access = false

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  eks_managed_node_groups = {
    default = {
      desired_size   = 2
      min_size       = 2
      max_size       = 3
      instance_types = ["t3.small"]
      subnets        = module.vpc.private_subnets
    }
  }

enable_cluster_creator_admin_permissions = true
  tags = {
    Project = local.project
  }
}

# Kubernetes 
data "aws_eks_cluster" "eks_cluster" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}
data "aws_eks_cluster_auth" "eks_auth" {
  name = module.eks.cluster_name
  depends_on = [module.eks]
}

provider "kubernetes" {
  host                   = data.aws_eks_cluster.eks_cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.eks_cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.eks_auth.token

}
#Nginx + Service LB

resource "kubernetes_namespace" "lab" {
  metadata { name = "lab2" }
}

resource "kubernetes_deployment" "web" {
  metadata {
    name      = "web-nginx"
    namespace = kubernetes_namespace.lab.metadata[0].name
    labels = { app = "web-nginx" }
  }
  spec {
    replicas = 2
    selector { match_labels = { app = "web-nginx" } }
    template {
      metadata { labels = { app = "web-nginx" } }
      spec {
        container {
          name  = "nginx"
          image = "nginx:stable"
          port { container_port = 80 }
        }
      }
    }
  }
}


resource "kubernetes_service" "web" {
  metadata {
    name      = "web-svc"
    namespace = kubernetes_namespace.lab.metadata[0].name
    labels    = { app = "web-nginx" }
  }
  spec {
    selector = { app = "web-nginx" }
    port {
      port        = 80
      target_port = 80
      protocol    = "TCP"
    }
    type = "LoadBalancer"
  }
}


# Outputs

output "alb_dns_name" {
  description = "Public URL of the ALB for EC2 web servers"
  value       = aws_lb.alb.dns_name
}

output "ec2_public_ips" {
  description = "Public IPs of the EC2 instances"
  value       = aws_instance.web[*].public_ip
}

output "eks_cluster_name" {
  value = module.eks.cluster_name
}

output "k8s_service_hostname" {
  description = "External hostname created for the Kubernetes LoadBalancer Service"
  value       = kubernetes_service.web.status[0].load_balancer[0].ingress[0].hostname
}



# set-Alias tf terraform => set alias for terraform command
# tf version => show the terraform version
# tf init => desploy all the information that my provide request (initializing the backend))
# tf init -upgrade => forece upgrade of the provider
# tf validate => validate the code
# tf plan => show what is going to be created
# tf fmt => format the code
# tf plan => show what is going to be created
# tf apply => apply the changes (create the infrastructure)
# tf apply -auto-approve => apply the changes without confirmation
# tf apply -target="module.eks" => apply the changes only for the eks module
# tf destroy => destroy the infrastructure
# tf variables -var-file="variables.tfvars" => create a variable file
# tf workspace list
# tf workspace new prod => create a new workspace
# tf workspace select default => select a workspace. you can changed default for another workspace
# k get nodes => see the nodes you have in console



#common errors: No default VPC for this user (fix by creating a VPC in the AWS console)
#common errors: The Kubernetes provider is attempting to initialize using cluster data that does not yet exist in the plan.
#common errors: Error: Provider "kubernetes" must be configured with a cluste before it can be used.
  #tf apply -target="module.vpc" -target="module.eks" => apply just VPC + EKS
  #aws eks update-kubeconfig --name lab2-terraform-eks --region us-east-1 



#Remove-Item -Recurse -Force .\.terraform => remove the .terraform folder very important for git 

#ssh-keygen -t rsa -b 2048 -f "nginx-server.key" => create ssh in console

# 1. to check with instance_type is free in the powershell:
  # aws ec2 describe-instance-types `
  # --filters Name=free-tier-eligible,Values=true `
  # --query "InstanceTypes[].InstanceType" `
  # --region us-east-1 `
  # --output table

# to check amis available in the powershell:
  # aws ec2 describe-images --owners amazon --filters "Name=name,Values=ubuntu/images/hvm-ssd/ubuntu-focal-20.04-amd64-server-*" --query "Images[*].[ImageId,Name,CreationDate]" --region us-east-1 --output table

#variables
  #1º Way to create a variable
    #variable access_key =>  $env:AWS_ACCESS_KEY_ID="YOUR_ACCESS_KEY" (replace YOUR_ACCESS_KEY with your actual AWS access key) - good practice to not hardcode sensitive info
    #variable secret_key =>  $env:AWS_SECRET_ACCESS_KEY="YOUR_SECRET_KEY (replace YOUR_SECRET_KEY with your actual AWS secret key) - good practice to not hardcode sensitive info
  #2º Way to create a variable (you need to create the variable.tf and terraform.tfvars)
    #provider "aws" {                          # AWS provider configuration
      #region = "us-east-1"
      #access_key = var.access_key    if I would be using the varibales way but I am using another.
      #secret_key = var.access_key}

#aws sts get-caller-identity => user I am using 
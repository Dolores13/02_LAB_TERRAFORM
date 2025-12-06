# Terraform Lab2 

This repository contains the work completed for my Terraform lab, where I built a complete cloud environment on AWS using Infrastructure as Code (IaC). Throughout this project, I learned how different pieces of cloud infrastructure fit together and how Terraform can automate the entire process in a clean and reproducible way.

---

## Project Overview

The objective of this lab was to design and deploy a functional cloud architecture that includes:

- A VPC with public and private subnets
- Two EC2 instances running Nginx
- An Application Load Balancer
- A fully managed EKS cluster with a Kubernetes workload

All resources were defined in Terraform using HCL (HashiCorp Configuration Language).

---

## Components Deployed

### 1. Networking (VPC)

A VPC was created with four subnets:

- Two public subnets used for the EC2 instances and the Application Load Balancer
- Two private subnets used for the EKS worker nodes

The VPC module handled routing tables, NAT Gateway configuration and DNS settings. This helped me understand how network components interact in real AWS environments.

---

### 2. Security Group

A security group was created with the following rules:

- SSH (port 22) allowed for access during the lab
- HTTP (port 80) allowed for web traffic
- Outbound traffic allowed to support updates and communication with external services

This section highlighted the importance of managing access correctly when deploying cloud infrastructure.

---

### 3. EC2 Instances

Two EC2 instances were deployed, one in each public subnet. Using the user_data feature, the instances automatically installed Nginx and generated a simple HTML page. This allowed me to confirm which instance was responding to incoming traffic. Seeing the service come online automatically after deployment was one of the most rewarding parts of the project.

---

### 4. Application Load Balancer (ALB)

An Application Load Balancer was deployed across both public subnets. It distributes traffic between the two EC2 instances and performs health checks to ensure availability. Configuring the ALB in Terraform helped me understand the concepts behind load balancing and high availability.

---

### 5. EKS Cluster and Kubernetes Workloads

The project also includes the deployment of:

- An Amazon EKS cluster (version 1.29)
- A managed node group running in private subnets
- IAM Roles for Service Accounts (IRSA) enabled for secure identity management
- A Kubernetes namespace, deployment and LoadBalancer service running Nginx
  
Deploying Kubernetes resources through Terraform helped me understand how infrastructure and container orchestration integrate in a DevOps environment.

---

## Terraform Outputs

Terraform provides several useful outputs at the end of the deployment, including:

- The public DNS of the Application Load Balancer
- The public IP addresses of the EC2 instances
- The name of the EKS cluster
- The hostname of the Kubernetes LoadBalancer service

These outputs made it easier to verify the functionality of the deployed resources without navigating through the AWS console.

---

## Common Terraform Commands Used
- terraform init
- terraform validate
- terraform fmt
- terraform plan
- terraform apply
- terraform destroy

Repeating this workflow improved my understanding of the Terraform lifecycle and the importance of planning infrastructure changes before applying them.

---

## What I Learned

This lab provided a practical understanding of several important concepts:

- How AWS networking works with VPCs, subnets and routing
- How EC2 instances and load balancers are configured
- How Kubernetes integrates with cloud services through EKS
- The importance of managing sensitive information correctly
- How Terraform manages dependencies and resource creation order
- The role of IaC in DevOps for automation, consistency and reproducibility

Overall, this project helped me build confidence in deploying real infrastructure using Terraform while reinforcing best practices across the entire workflow.

---

## Author

María Dolores Martos Cabrera  
Postgraduate Diploma in DevOps – ATU Donegal (2025)


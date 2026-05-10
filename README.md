# Much-To-Do Infrastructure

This repository contains the Infrastructure as Code (IaC) for the Much-To-Do task management application, built using Terraform and deployed on AWS.

## Architecture Overview

The infrastructure is deployed across two Availability Zones in `us-east-1` for high availability.

### Components

**Networking**
- VPC with CIDR `10.0.0.0/16`
- 2 Public Subnets across AZ-a and AZ-b
- 2 Private Subnets across AZ-a and AZ-b
- Internet Gateway for public internet access
- 2 NAT Gateways for private subnet outbound access
- Public and Private Route Tables

**Frontend**
- S3 Bucket hosting React SPA build assets
- CloudFront Distribution serving content over HTTPS
- Origin Access Control (OAC) for secure S3 access

**Backend**
- Application Load Balancer (ALB) in public subnets
- 2 EC2 instances (t3.small) in private subnets running the Go API
- Systemd service managing the Go backend process
- IAM roles with SSM access and CloudWatch permissions

**Database**
- MongoDB 7 on EC2 in a private subnet
- ElastiCache Redis cluster for caching

**Security**
- ALB Security Group: allows port 80/443 from internet
- Backend Security Group: allows port 8080 from ALB only
- MongoDB Security Group: allows port 27017 from backend only
- Redis Security Group: allows port 6379 from backend only

**Observability**
- CloudWatch Log Groups for backend and system logs
- CloudWatch Metric Alarms for healthy host count and CPU usage
- CloudWatch Agent on EC2 instances shipping logs

## Repository Structure

much-to-do-infra/
├── main.tf                          # Root module
├── variables.tf                     # Input variables
├── outputs.tf                       # Output values
├── backend.tf                       # S3 remote state config
├── terraform.tfvars                 # Variable values (not committed)
└── modules/
├── networking/                  # VPC, subnets, gateways
├── security/                    # Security groups
├── frontend/                    # S3 + CloudFront
├── backend/                     # ALB + EC2 + IAM
├── database/                    # MongoDB + Redis
└── observability/               # CloudWatch

## Prerequisites

- Terraform >= 1.3.0
- AWS CLI configured with appropriate credentials
- An existing EC2 Key Pair
- S3 bucket for Terraform remote state
- DynamoDB table for state locking

## Remote State

Terraform state is stored remotely in S3 with DynamoDB locking:

- **S3 Bucket:** `much-to-do-tfstate-bucket-dale`
- **DynamoDB Table:** `much-to-do-tf-locks`
- **State Key:** `prod/terraform.tfstate`

## Usage

### 1. Clone the repository

```bash
git clone https://github.com/dale-code/much-to-do-infra.git
cd much-to-do-infra
```

### 2. Create terraform.tfvars

```hcl
aws_region        = "us-east-1"
project_name      = "much-to-do"
environment       = "production"
ec2_instance_type = "t3.small"
ec2_key_pair_name = "your-key-pair-name"
mongo_username    = "muchtodousr"
mongo_password    = "your-mongo-password"
mongo_db_name     = "much_todo_db"
jwt_secret_key    = "your-jwt-secret"
```

### 3. Initialize and apply

```bash
terraform init
terraform plan
terraform apply
```

### 4. Outputs

After apply, Terraform outputs:

| Output | Description |
|---|---|
| `cloudfront_url` | Frontend CloudFront URL |
| `alb_dns_name` | Backend ALB DNS name |
| `mongo_private_ip` | MongoDB private IP |
| `redis_endpoint` | Redis cluster endpoint |

## Security Notes

- All compute resources are in private subnets
- No SSH ports exposed — access via AWS Systems Manager (SSM)
- Secrets managed via `terraform.tfvars` which is excluded from Git
- S3 state bucket encryption enabled
- EBS volumes encrypted

## CI/CD Integration

The backend EC2 instances are configured to receive deployments via AWS SSM from the GitHub Actions pipeline in the application repository. The pipeline builds the Go binary and deploys it without requiring SSH access.

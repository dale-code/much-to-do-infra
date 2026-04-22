variable "aws_region" {
  description = "AWS region to deploy into"
  default     = "us-east-1"
}

variable "project_name" {
  description = "Used to name all resources"
  default     = "much-to-do"
}

variable "environment" {
  description = "Deployment environment"
  default     = "production"
}

variable "ec2_instance_type" {
  description = "EC2 instance type for backend and database servers"
  default     = "t3.micro"
}

variable "ec2_key_pair_name" {
  description = "Name of your EC2 key pair for SSH access"
  type        = string
}

variable "availability_zones" {
  description = "Two AZs to deploy across"
  default     = ["us-east-1a", "us-east-1b"]
}

variable "public_subnet_cidrs" {
  description = "CIDR blocks for public subnets"
  default     = ["10.0.1.0/24", "10.0.2.0/24"]
}

variable "private_subnet_cidrs" {
  description = "CIDR blocks for private subnets"
  default     = ["10.0.10.0/24", "10.0.11.0/24"]
}

variable "mongo_username" {
  description = "MongoDB root username"
  default     = "muchtodousr"
}

variable "mongo_password" {
  description = "MongoDB root password"
  type        = string
  sensitive   = true
}

variable "mongo_db_name" {
  description = "MongoDB database name"
  default     = "much_todo_db"
}

variable "jwt_secret_key" {
  description = "Secret key for signing JWTs"
  type        = string
  sensitive   = true
}

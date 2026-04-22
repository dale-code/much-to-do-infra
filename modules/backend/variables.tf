variable "project_name" {
  description = "Project name used for naming resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "vpc_id" {
  description = "ID of the VPC"
  type        = string
}

variable "public_subnet_ids" {
  description = "IDs of public subnets for the ALB"
  type        = list(string)
}

variable "private_subnet_ids" {
  description = "IDs of private subnets for EC2 instances"
  type        = list(string)
}

variable "alb_sg_id" {
  description = "Security group ID for the ALB"
  type        = string
}

variable "backend_sg_id" {
  description = "Security group ID for backend EC2 instances"
  type        = string
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
  default     = "t3.micro"
}

variable "key_pair_name" {
  description = "EC2 key pair name"
  type        = string
}

variable "mongo_host" {
  description = "Private IP of the MongoDB instance"
  type        = string
}

variable "mongo_username" {
  description = "MongoDB username"
  type        = string
}

variable "mongo_password" {
  description = "MongoDB password"
  type        = string
  sensitive   = true
}

variable "mongo_db_name" {
  description = "MongoDB database name"
  type        = string
}

variable "redis_host" {
  description = "Redis endpoint hostname"
  type        = string
}

variable "jwt_secret_key" {
  description = "JWT signing secret"
  type        = string
  sensitive   = true
}

variable "cloudfront_domain" {
  description = "CloudFront domain name for CORS allowed origins"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo in format username/repo-name"
  type        = string
  default     = "Innocent9712/much-to-do"
}

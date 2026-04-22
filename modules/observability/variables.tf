variable "project_name" {
  description = "Project name used for naming resources"
  type        = string
}

variable "environment" {
  description = "Deployment environment"
  type        = string
}

variable "instance_ids" {
  description = "IDs of the backend EC2 instances to monitor"
  type        = list(string)
}

variable "target_group_arn" {
  description = "ARN of the ALB target group for health monitoring"
  type        = string
}

variable "alb_arn" {
  description = "ARN of the Application Load Balancer"
  type        = string
}

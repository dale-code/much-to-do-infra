output "alb_sg_id" {
  description = "Security group ID for the ALB"
  value       = aws_security_group.alb.id
}

output "backend_sg_id" {
  description = "Security group ID for backend EC2 instances"
  value       = aws_security_group.backend.id
}

output "mongodb_sg_id" {
  description = "Security group ID for MongoDB"
  value       = aws_security_group.mongodb.id
}

output "redis_sg_id" {
  description = "Security group ID for Redis"
  value       = aws_security_group.redis.id
}

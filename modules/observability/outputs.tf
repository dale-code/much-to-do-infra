output "backend_log_group_name" {
  description = "CloudWatch log group name for backend logs"
  value       = aws_cloudwatch_log_group.backend.name
}

output "system_log_group_name" {
  description = "CloudWatch log group name for system logs"
  value       = aws_cloudwatch_log_group.system.name
}

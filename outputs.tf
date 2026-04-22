output "cloudfront_url" {
  description = "Frontend CloudFront URL"
  value       = module.frontend.cloudfront_domain_name
}

output "alb_dns_name" {
  description = "Backend ALB DNS name"
  value       = module.backend.alb_dns_name
}

output "redis_endpoint" {
  description = "Redis endpoint"
  value       = module.database.redis_host
}

output "mongo_private_ip" {
  description = "MongoDB private IP"
  value       = module.database.mongo_private_ip
}

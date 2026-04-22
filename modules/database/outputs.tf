output "mongo_private_ip" {
  description = "Private IP of the MongoDB EC2 instance"
  value       = aws_instance.mongodb.private_ip
}

output "redis_host" {
  description = "Redis cluster endpoint hostname"
  value       = aws_elasticache_cluster.redis.cache_nodes[0].address
}

output "redis_port" {
  description = "Redis port"
  value       = aws_elasticache_cluster.redis.port
}

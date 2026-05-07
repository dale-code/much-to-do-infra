# IAM Role for MongoDB EC2 — allows SSM access so you can connect without SSH
resource "aws_iam_role" "mongodb" {
  name = "${var.project_name}-mongodb-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })
  tags = {
    Name        = "${var.project_name}-mongodb-role"
    Environment = var.environment
  }
}

# Attach SSM policy so you can connect via AWS Systems Manager
resource "aws_iam_role_policy_attachment" "mongodb_ssm" {
  role       = aws_iam_role.mongodb.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "mongodb" {
  name = "${var.project_name}-mongodb-profile"
  role = aws_iam_role.mongodb.name
}

# MongoDB EC2 Instance
resource "aws_instance" "mongodb" {
  ami                    = "ami-0102a36b3e9d5e4df"
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[0]
  vpc_security_group_ids = [var.mongodb_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.mongodb.name
  key_name               = var.key_pair_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/userdata-mongodb.sh", {
    mongo_username = var.mongo_username
    mongo_password = var.mongo_password
    mongo_db_name  = var.mongo_db_name
  }))

  tags = {
    Name        = "${var.project_name}-mongodb"
    Environment = var.environment
  }
}

# ElastiCache Subnet Group — tells Redis which subnets it can use
resource "aws_elasticache_subnet_group" "redis" {
  name       = "${var.project_name}-redis-subnet-group"
  subnet_ids = var.private_subnet_ids

  tags = {
    Name        = "${var.project_name}-redis-subnet-group"
    Environment = var.environment
  }
}

# ElastiCache Redis Cluster
resource "aws_elasticache_cluster" "redis" {
  cluster_id           = "${var.project_name}-redis"
  engine               = "redis"
  node_type            = "cache.t3.micro"
  num_cache_nodes      = 1
  parameter_group_name = "default.redis7"
  engine_version       = "7.0"
  port                 = 6379
  subnet_group_name    = aws_elasticache_subnet_group.redis.name
  security_group_ids   = [var.redis_sg_id]

  tags = {
    Name        = "${var.project_name}-redis"
    Environment = var.environment
  }
}

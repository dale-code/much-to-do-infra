
# Fetch the latest Amazon Linux 2023 AMI
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

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
  ami                    = data.aws_ami.amazon_linux.id
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

  # Startup script — installs and configures MongoDB with auth
  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Install MongoDB 7
    cat > /etc/yum.repos.d/mongodb-org-7.0.repo << 'REPO'
    [mongodb-org-7.0]
    name=MongoDB Repository
    baseurl=https://repo.mongodb.org/yum/amazon/2023/mongodb-org/7.0/x86_64/
    gpgcheck=1
    enabled=1
    gpgkey=https://pgp.mongodb.com/server-7.0.asc
    REPO

    dnf install -y mongodb-org

    # Start and enable MongoDB
    systemctl start mongod
    systemctl enable mongod

    # Wait for MongoDB to be ready
    sleep 10

    # Create admin user with authentication
    mongosh --eval "
      use admin
      db.createUser({
        user: '${var.mongo_username}',
        pwd: '${var.mongo_password}',
        roles: [
          { role: 'userAdminAnyDatabase', db: 'admin' },
          { role: 'readWriteAnyDatabase', db: 'admin' }
        ]
      })
    "

    # Enable MongoDB authentication
    sed -i 's/#security:/security:\n  authorization: enabled/' /etc/mongod.conf

    # Allow connections from within the VPC (not just localhost)
    sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf

    # Restart MongoDB to apply changes
    systemctl restart mongod

    echo "MongoDB setup complete"
  EOF
  )

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


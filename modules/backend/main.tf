# IAM Role for backend EC2 — allows SSM access and CloudWatch logging
resource "aws_iam_role" "backend" {
  name = "${var.project_name}-backend-role"

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
    Name        = "${var.project_name}-backend-role"
    Environment = var.environment
  }
}

# SSM access — lets you connect to instances without SSH
resource "aws_iam_role_policy_attachment" "backend_ssm" {
  role       = aws_iam_role.backend.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

# CloudWatch agent — lets instances ship logs
resource "aws_iam_role_policy_attachment" "backend_cloudwatch" {
  role       = aws_iam_role.backend.name
  policy_arn = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
}

# S3 access for pulling deployment artifacts
resource "aws_iam_role_policy" "backend_s3" {
  name = "${var.project_name}-backend-s3-policy"
  role = aws_iam_role.backend.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:ListBucket"
        ]
        Resource = [
          "arn:aws:s3:::${var.project_name}-frontend-${var.environment}",
          "arn:aws:s3:::${var.project_name}-frontend-${var.environment}/*"
        ]
      }
    ]
  })
}

resource "aws_iam_instance_profile" "backend" {
  name = "${var.project_name}-backend-profile"
  role = aws_iam_role.backend.name
}

# Application Load Balancer
resource "aws_lb" "main" {
  name               = "${var.project_name}-alb"
  internal           = false
  load_balancer_type = "application"
  security_groups    = [var.alb_sg_id]
  subnets            = var.public_subnet_ids

  enable_deletion_protection = false

  tags = {
    Name        = "${var.project_name}-alb"
    Environment = var.environment
  }
}

# Target Group
resource "aws_lb_target_group" "backend" {
  name     = "${var.project_name}-tg"
  port     = 8080
  protocol = "HTTP"
  vpc_id   = var.vpc_id

  health_check {
    enabled             = true
    path                = "/ping"
    port                = "traffic-port"
    protocol            = "HTTP"
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 5
    interval            = 30
    matcher             = "200"
  }

  tags = {
    Name        = "${var.project_name}-tg"
    Environment = var.environment
  }
}

# ALB Listener
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# Backend EC2 Instances
resource "aws_instance" "backend" {
  count                  = 2
  ami                    = "ami-0102a36b3e9d5e4df"
  instance_type          = var.instance_type
  subnet_id              = var.private_subnet_ids[count.index]
  vpc_security_group_ids = [var.backend_sg_id]
  iam_instance_profile   = aws_iam_instance_profile.backend.name
  key_name               = var.key_pair_name

  root_block_device {
    volume_size = 30
    volume_type = "gp3"
    encrypted   = true
  }

  user_data = base64encode(templatefile("${path.module}/userdata-backend.sh", {
    mongo_username    = var.mongo_username
    mongo_password    = var.mongo_password
    mongo_host        = var.mongo_host
    mongo_db_name     = var.mongo_db_name
    redis_host        = var.redis_host
    jwt_secret_key    = var.jwt_secret_key
    cloudfront_domain = var.cloudfront_domain
    github_repo       = var.github_repo
  }))

  tags = {
    Name        = "${var.project_name}-backend-${count.index + 1}"
    Environment = var.environment
  }
}

# Register EC2 instances with the target group
resource "aws_lb_target_group_attachment" "backend" {
  count            = 2
  target_group_arn = aws_lb_target_group.backend.arn
  target_id        = aws_instance.backend[count.index].id
  port             = 8080
}

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

# Target Group — the ALB uses this to know which EC2s to send traffic to
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

# ALB Listener — listens on port 80 and forwards to target group
resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.main.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend.arn
  }
}

# Backend EC2 Instances — two across different AZs
resource "aws_instance" "backend" {
  count                  = 2
  ami                    = data.aws_ami.amazon_linux.id
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

  user_data = base64encode(<<-EOF
    #!/bin/bash
    set -e

    # Install dependencies
    dnf install -y golang git amazon-cloudwatch-agent

    # Create app directory and user
    useradd -r -s /bin/false appuser
    mkdir -p /opt/much-to-do
    chown appuser:appuser /opt/much-to-do

    # Write environment file
    cat > /opt/much-to-do/.env << 'ENVFILE'
    PORT=8080
    MONGO_URI=mongodb://${var.mongo_username}:${var.mongo_password}@${var.mongo_host}:27017/${var.mongo_db_name}?authSource=admin
    DB_NAME=${var.mongo_db_name}
    JWT_SECRET_KEY=${var.jwt_secret_key}
    JWT_EXPIRATION_HOURS=72
    ENABLE_CACHE=true
    REDIS_ADDR=${var.redis_host}:6379
    REDIS_PASSWORD=
    LOG_LEVEL=INFO
    LOG_FORMAT=json
    ALLOWED_ORIGINS=https://${var.cloudfront_domain}
    COOKIE_DOMAINS=${var.cloudfront_domain}
    SECURE_COOKIE=true
    ENVFILE

    chown appuser:appuser /opt/much-to-do/.env
    chmod 600 /opt/much-to-do/.env

    # Clone the application
    git clone -b feature/full-stack https://github.com/${var.github_repo}.git /tmp/much-to-do
    cp -r /tmp/much-to-do/Server/MuchToDo/* /opt/much-to-do/
    chown -R appuser:appuser /opt/much-to-do

    # Build the Go binary
    cd /opt/much-to-do
    go build -o much-to-do-server ./cmd/api/

    # Create systemd service
    cat > /etc/systemd/system/much-to-do.service << 'SERVICE'
    [Unit]
    Description=MuchToDo API Server
    After=network.target

    [Service]
    Type=simple
    User=appuser
    WorkingDirectory=/opt/much-to-do
    ExecStart=/opt/much-to-do/much-to-do-server
    Restart=always
    RestartSec=5
    StandardOutput=journal
    StandardError=journal
    SyslogIdentifier=much-to-do

    [Install]
    WantedBy=multi-user.target
    SERVICE

    systemctl daemon-reload
    systemctl enable much-to-do
    systemctl start much-to-do

    # Configure CloudWatch agent
    cat > /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json << 'CW'
    {
      "logs": {
        "logs_collected": {
          "files": {
            "collect_list": [
              {
                "file_path": "/var/log/much-to-do.log",
                "log_group_name": "/much-to-do/production/backend",
                "log_stream_name": "{instance_id}",
                "timezone": "UTC"
              }
            ]
          }
        }
      }
    }
    CW

    # Also capture journald logs for the app
    cat > /etc/systemd/journald.conf.d/much-to-do.conf << 'JOURNAL'
    [Journal]
    ForwardToSyslog=yes
    JOURNAL

    /opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
      -a fetch-config \
      -m ec2 \
      -s \
      -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

    echo "Backend setup complete"
  EOF
  )

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

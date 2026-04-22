# CloudWatch Log Group for the backend application
resource "aws_cloudwatch_log_group" "backend" {
  name              = "/${var.project_name}/${var.environment}/backend"
  retention_in_days = 30

  tags = {
    Name        = "${var.project_name}-backend-logs"
    Environment = var.environment
  }
}

# CloudWatch Log Group for system logs
resource "aws_cloudwatch_log_group" "system" {
  name              = "/${var.project_name}/${var.environment}/system"
  retention_in_days = 7

  tags = {
    Name        = "${var.project_name}-system-logs"
    Environment = var.environment
  }
}

# CloudWatch Metric Alarm — alerts if both instances are unhealthy
resource "aws_cloudwatch_metric_alarm" "healthy_hosts" {
  alarm_name          = "${var.project_name}-healthy-hosts"
  comparison_operator = "LessThanThreshold"
  evaluation_periods  = 2
  metric_name         = "HealthyHostCount"
  namespace           = "AWS/ApplicationELB"
  period              = 60
  statistic           = "Average"
  threshold           = 1
  alarm_description   = "Alert when fewer than 1 backend instance is healthy"

  dimensions = {
    TargetGroup  = var.target_group_arn
    LoadBalancer = var.alb_arn
  }

  tags = {
    Name        = "${var.project_name}-healthy-hosts-alarm"
    Environment = var.environment
  }
}

# CloudWatch Metric Alarm — alerts on high CPU usage
resource "aws_cloudwatch_metric_alarm" "high_cpu" {
  count               = length(var.instance_ids)
  alarm_name          = "${var.project_name}-high-cpu-${count.index + 1}"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 2
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = 120
  statistic           = "Average"
  threshold           = 80
  alarm_description   = "Alert when CPU exceeds 80%"

  dimensions = {
    InstanceId = var.instance_ids[count.index]
  }

  tags = {
    Name        = "${var.project_name}-high-cpu-alarm-${count.index + 1}"
    Environment = var.environment
  }
}

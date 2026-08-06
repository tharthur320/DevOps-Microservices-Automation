# =====================================================================
# PROJECT: ENTERPRISE INFRASTRUCTURE OBSERVABILITY & MONITORING PIPELINE
# AUTOMATED CLOUDWATCH ALARMS & SNS THREAT TELEMETRY TOPOLOGY
# =====================================================================

provider "aws" {
  region = "us-east-1"
}

# 1. Reference a Mock Target Network Instance Layer for Telemetry Tracking
resource "aws_vpc" "monitor_vpc" {
  cidr_block           = "10.80.0.0/16"
  enable_dns_hostnames = true
  tags                 = { Name = "Observability-Core-Network" }
}

resource "aws_subnet" "monitor_subnet" {
  vpc_id            = aws_vpc.monitor_vpc.id
  cidr_block        = "10.80.1.0/24"
  availability_zone = "us-east-1a"
}

resource "aws_instance" "target_production_server" {
  ami           = "ami-0c7217cdde317cfec" # Secure Amazon Linux 2023 baseline AMI
  instance_type = "t2.micro"
  subnet_id     = aws_subnet.monitor_subnet.id

  tags = { Name = "Production-Core-ComputeNode" }
}

# 2. Deploy an Enterprise Amazon SNS (Simple Notification Service) Alert Topic
resource "aws_sns_topic" "infrastructure_alerts" {
  name = "enterprise-infrastructure-anomaly-alerts"

  tags = {
    Layer      = "Telemetry-Alerting"
    SavedAsset = "True"
  }
}

# 3. Create a Secure CloudWatch Metric Alarm Tracking Compute Stress
resource "aws_cloudwatch_metric_alarm" "cpu_high_alarm" {
  alarm_name          = "Production-Server-High-CPU-Utilization"
  comparison_operator = "GreaterThanOrEqualToThreshold"
  evaluation_periods  = "2" # Evaluate metrics over two consecutive checking cycles
  metric_name         = "CPUUtilization"
  namespace           = "AWS/EC2"
  period              = "120" # Sample telemetry snapshot data points every 120 seconds
  statistic           = "Average"
  threshold           = "80" # Alert trigger threshold metric: 80% total CPU usage
  alarm_description   = "Automated trigger firing if compute node experiences continuous high-load anomalies."

  # Bind the Metric Alarm to watch our specific target production server instance
  dimensions = {
    InstanceId = aws_instance.target_production_server.id
  }

  # Action routing: Direct real-time alerts straight down to our secure SNS notification topic
  alarm_actions = [aws_sns_topic.infrastructure_alerts.arn]
}

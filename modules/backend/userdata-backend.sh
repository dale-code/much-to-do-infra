#!/bin/bash
set -e

# Install dependencies
dnf install -y golang git amazon-cloudwatch-agent

# Create app user and directory
useradd -r -s /bin/false appuser
mkdir -p /opt/much-to-do
chown appuser:appuser /opt/much-to-do

# Write environment file
cat > /opt/much-to-do/.env << 'ENVFILE'
PORT=8080
MONGO_URI=mongodb://${mongo_username}:${mongo_password}@${mongo_host}:27017/${mongo_db_name}?authSource=admin
DB_NAME=${mongo_db_name}
JWT_SECRET_KEY=${jwt_secret_key}
JWT_EXPIRATION_HOURS=72
ENABLE_CACHE=true
REDIS_ADDR=${redis_host}:6379
REDIS_PASSWORD=
LOG_LEVEL=INFO
LOG_FORMAT=json
ALLOWED_ORIGINS=https://${cloudfront_domain}
COOKIE_DOMAINS=${cloudfront_domain}
SECURE_COOKIE=true
ENVFILE

chown appuser:appuser /opt/much-to-do/.env
chmod 600 /opt/much-to-do/.env

# Clone the application
git clone -b feature/full-stack https://github.com/${github_repo}.git /tmp/much-to-do
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

/opt/aws/amazon-cloudwatch-agent/bin/amazon-cloudwatch-agent-ctl \
  -a fetch-config \
  -m ec2 \
  -s \
  -c file:/opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json

echo "Backend setup complete"

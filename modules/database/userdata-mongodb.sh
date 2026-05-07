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

# Create admin user
mongosh --eval "
  use admin
  db.createUser({
    user: '${mongo_username}',
    pwd: '${mongo_password}',
    roles: [
      { role: 'userAdminAnyDatabase', db: 'admin' },
      { role: 'readWriteAnyDatabase', db: 'admin' }
    ]
  })
"

# Enable authentication
sed -i 's/#security:/security:\n  authorization: enabled/' /etc/mongod.conf

# Allow VPC connections
sed -i 's/bindIp: 127.0.0.1/bindIp: 0.0.0.0/' /etc/mongod.conf

# Restart to apply changes
systemctl restart mongod

echo "MongoDB setup complete"

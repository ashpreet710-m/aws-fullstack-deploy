#!/bin/bash
set -e
# install docker
yum update -y || apt-get update -y
if command -v yum >/dev/null 2>&1; then
  amazon-linux-extras install docker -y || yum install -y docker
else
  apt-get install -y docker.io
fi
service docker start
usermod -a -G docker ec2-user || true

# install docker-compose (simple)
curl -L "https://github.com/docker/compose/releases/download/2.23.3/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# clone repo and run backend docker
cd /home/ec2-user
REPO="${repo_url}"
if [ -d app_repo ]; then rm -rf app_repo; fi
git clone "${repo}" app_repo
cd app_repo/backend

# create .env with instance id
cat > .env <<EOF
INSTANCE_ID=${instance_id}
EOF

# build and run
/usr/local/bin/docker-compose -f - up -d <<'EOF'
version: "3"
services:
  backend:
    build: .
    ports:
      - "5000:5000"
    env_file:
      - .env
EOF

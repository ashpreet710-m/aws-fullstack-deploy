terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.region
}

# Find latest Amazon Linux 2 AMI if not provided
data "aws_ami" "amazon_linux" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

locals {
  ami_id = length(var.ami) > 0 ? var.ami : data.aws_ami.amazon_linux.id
}

# Security groups
resource "aws_security_group" "frontend_sg" {
  name        = "frontend-sg"
  description = "Allow HTTP"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    description = "HTTP"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

resource "aws_security_group" "backend_sg" {
  name        = "backend-sg"
  description = "Allow HTTP 5000 and ALB health"
  vpc_id      = data.aws_vpc.default.id
  ingress {
    description = "App port"
    from_port   = 5000
    to_port     = 5000
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  ingress {
    description = "ALB health"
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
}

# Use default VPC
data "aws_vpc" "default" {
  default = true
}

data "aws_subnet_ids" "default" {
  vpc_id = data.aws_vpc.default.id
}

# IAM role for instance (optional) - not used here

# Application Load Balancer
resource "aws_lb" "alb" {
  name               = "app-alb"
  internal           = false
  load_balancer_type = "application"
  subnets            = data.aws_subnet_ids.default.ids
  security_groups    = [aws_security_group.frontend_sg.id]
}

resource "aws_lb_target_group" "backend_tg" {
  name     = "backend-tg"
  port     = 5000
  protocol = "HTTP"
  vpc_id   = data.aws_vpc.default.id
  health_check {
    path                = "/health"
    matcher             = "200-499"
    interval            = 30
    timeout             = 5
    healthy_threshold   = 2
    unhealthy_threshold = 2
  }
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = "80"
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.backend_tg.arn
  }
}

# Create two backend EC2 instances that will run backend container
resource "aws_instance" "backend" {
  count         = 2
  ami           = local.ami_id
  instance_type = var.instance_type
  subnet_id     = element(data.aws_subnet_ids.default.ids, count.index % length(data.aws_subnet_ids.default.ids))
  key_name      = length(var.key_name) > 0 ? var.key_name : null
  vpc_security_group_ids = [aws_security_group.backend_sg.id]
  user_data = templatefile("${path.module}/user_data_backend.sh.tpl", {
    repo_url = "https://github.com/${replace(var.repo, "https://github.com/", "")}"
    instance_id = "backend-${count.index}"
    alb_dns = aws_lb.alb.dns_name
  })

  tags = {
    Name = "backend-${count.index}"
  }
}

# Attach backend instances to ALB target group
resource "aws_lb_target_group_attachment" "tg_attach" {
  count            = length(aws_instance.backend)
  target_group_arn = aws_lb_target_group.backend_tg.arn
  target_id        = aws_instance.backend[count.index].id
  port             = 5000
}

# Frontend EC2
resource "aws_instance" "frontend" {
  ami           = local.ami_id
  instance_type = var.instance_type
  subnet_id     = element(data.aws_subnet_ids.default.ids, 0)
  key_name      = length(var.key_name) > 0 ? var.key_name : null
  vpc_security_group_ids = [aws_security_group.frontend_sg.id]
  user_data = templatefile("${path.module}/user_data_frontend.sh.tpl", {
    repo_url = "https://github.com/${replace(var.repo, "https://github.com/", "")}"
    alb_dns = aws_lb.alb.dns_name
  })
  tags = { Name = "frontend" }
}

# Output ALB DNS
output "alb_dns" {
  value = aws_lb.alb.dns_name
}

# required variable repo (full https url)
variable "repo" {
  type = string
}

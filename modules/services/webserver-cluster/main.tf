data "aws_availability_zones" "available" {}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 2)

  http_port    = 80
  any_port     = 0
  any_protocol = "-1"
  tcp_protocol = "tcp"
  all_ips      = ["0.0.0.0/0"]
  app_port     = var.ingress_ports[0]

  # Environment-based logic
  instance_type = var.environment == "production" ? "t3.medium" : var.instance_type

  common_tags = {
    Environment = var.cluster_name
  }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = local.common_tags
}

# IGW
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = local.common_tags
}

# Subnets using for_each (FIXED)
resource "aws_subnet" "public" {
  for_each = {
    for idx, cidr in var.public_subnet_cidrs :
    idx => cidr
  }

  vpc_id                  = aws_vpc.main.id
  cidr_block              = each.value
  availability_zone       = local.azs[tonumber(each.key)]
  map_public_ip_on_launch = true

  tags = local.common_tags
}

# Route table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = local.common_tags
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

# Route associations using for_each
resource "aws_route_table_association" "subnets" {
  for_each = aws_subnet.public

  subnet_id      = each.value.id
  route_table_id = aws_route_table.public.id
}

# Security Group
resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.main.id
  tags   = local.common_tags
}

# Ingress using for_each
resource "aws_security_group_rule" "instance_ingress" {
  for_each = {
    for port in var.ingress_ports :
    port => port
  }

  type              = "ingress"
  security_group_id = aws_security_group.instance_sg.id
  from_port         = each.value
  to_port           = each.value
  protocol          = local.tcp_protocol
  cidr_blocks       = local.all_ips
}

resource "aws_security_group_rule" "instance_egress" {
  type              = "egress"
  security_group_id = aws_security_group.instance_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = local.any_protocol
  cidr_blocks       = local.all_ips
}

# ALB SG
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id
  tags   = local.common_tags
}

resource "aws_security_group_rule" "alb_ingress" {
  type              = "ingress"
  security_group_id = aws_security_group.alb_sg.id
  from_port         = local.http_port
  to_port           = local.http_port
  protocol          = local.tcp_protocol
  cidr_blocks       = local.all_ips
}

resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  security_group_id = aws_security_group.alb_sg.id
  from_port         = local.any_port
  to_port           = local.any_port
  protocol          = local.any_protocol
  cidr_blocks       = local.all_ips
}

# Launch Template with conditional instance type
resource "aws_launch_template" "web" {
  name_prefix   = var.cluster_name
  image_id      = var.ami_id
  instance_type = local.instance_type

  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  user_data = base64encode(<<-EOF
              #!/bin/bash
              echo "Hello from ${var.cluster_name}" > index.html
              nohup busybox httpd -f -p ${local.app_port} &
              EOF
  )

  tags = local.common_tags
}

# ALB
resource "aws_lb" "alb" {
  name               = var.cluster_name
  load_balancer_type = "application"

  subnets         = values(aws_subnet.public)[*].id
  security_groups = [aws_security_group.alb_sg.id]

  tags = local.common_tags
}

resource "aws_lb_target_group" "tg" {
  name     = var.cluster_name
  port     = local.app_port
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path = "/"
    port = local.app_port
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = local.http_port
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# ASG
resource "aws_autoscaling_group" "asg" {
  min_size = var.min_size
  max_size = var.max_size

  vpc_zone_identifier = values(aws_subnet.public)[*].id

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  target_group_arns = [aws_lb_target_group.tg.arn]

  health_check_type         = "ELB"
  health_check_grace_period = 300
}

# CONDITIONAL resource
resource "aws_autoscaling_policy" "scale_out" {
  count = var.enable_autoscaling ? 1 : 0

  name                   = "${var.cluster_name}-scale-out"
  autoscaling_group_name = aws_autoscaling_group.asg.name
  adjustment_type        = "ChangeInCapacity"
  scaling_adjustment     = 1
  cooldown               = 300
}

# Data sources (unchanged, correct)
data "aws_instances" "asg_instances" {
  filter {
    name   = "tag:Environment"
    values = [var.cluster_name]
  }

  filter {
    name   = "instance-state-name"
    values = ["running"]
  }
}

data "aws_instance" "asg_instance" {
  for_each    = toset(data.aws_instances.asg_instances.ids)
  instance_id = each.value
}
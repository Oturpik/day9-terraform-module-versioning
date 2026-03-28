# Fetch availability zones
data "aws_availability_zones" "available" {}

# Centralized locals for all conditional logic
locals {
  is_production      = var.environment == "production"
  instance_type       = var.instance_type_override != "" ? var.instance_type_override : (local.is_production ? "t2.medium" : "t2.micro")
  min_size            = var.min_size_override != 0 ? var.min_size_override : (local.is_production ? 3 : 1)
  max_size            = var.max_size_override != 0 ? var.max_size_override : (local.is_production ? 10 : 3)
  http_ports          = var.server_ports
  common_tags         = { Environment = var.cluster_name }
}

# VPC
resource "aws_vpc" "main" {
  cidr_block = var.vpc_cidr
  tags       = local.common_tags
}

# Internet Gateway
resource "aws_internet_gateway" "igw" {
  vpc_id = aws_vpc.main.id
  tags   = local.common_tags
}

# Public Subnets
resource "aws_subnet" "public" {
  count                   = length(var.public_subnet_cidrs)
  vpc_id                  = aws_vpc.main.id
  cidr_block              = var.public_subnet_cidrs[count.index]
  map_public_ip_on_launch = true
  availability_zone       = data.aws_availability_zones.available.names[count.index]
  tags                    = local.common_tags
}

# Route Table
resource "aws_route_table" "public" {
  vpc_id = aws_vpc.main.id
  tags   = local.common_tags
}

resource "aws_route" "internet_access" {
  route_table_id         = aws_route_table.public.id
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = aws_internet_gateway.igw.id
}

resource "aws_route_table_association" "subnets" {
  count          = length(var.public_subnet_cidrs)
  subnet_id      = aws_subnet.public[count.index].id
  route_table_id = aws_route_table.public.id
}

# Security Groups
resource "aws_security_group" "instance_sg" {
  vpc_id = aws_vpc.main.id
  tags   = local.common_tags
}

resource "aws_security_group_rule" "instance_ingress" {
  for_each = { for p in local.http_ports : tostring(p) => p }  # convert number list to string map

  type              = "ingress"
  security_group_id = aws_security_group.instance_sg.id
  from_port         = each.value
  to_port           = each.value
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "instance_egress" {
  type              = "egress"
  security_group_id = aws_security_group.instance_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# ALB
resource "aws_security_group" "alb_sg" {
  vpc_id = aws_vpc.main.id
  tags   = local.common_tags
}

resource "aws_security_group_rule" "alb_ingress" {
  type              = "ingress"
  security_group_id = aws_security_group.alb_sg.id
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  cidr_blocks       = ["0.0.0.0/0"]
}

resource "aws_security_group_rule" "alb_egress" {
  type              = "egress"
  security_group_id = aws_security_group.alb_sg.id
  from_port         = 0
  to_port           = 0
  protocol          = "-1"
  cidr_blocks       = ["0.0.0.0/0"]
}

# Launch Template
resource "aws_launch_template" "web" {
  name_prefix   = var.cluster_name
  image_id      = var.ami_id
  instance_type = local.instance_type
  vpc_security_group_ids = [aws_security_group.instance_sg.id]

  user_data = base64encode(<<-EOF
                #!/bin/bash
                echo "Hello from ${var.cluster_name}" > index.html
                nohup busybox httpd -f -p ${local.http_ports[0]} &
                EOF
  )

  tags = local.common_tags
}

# ALB
resource "aws_lb" "alb" {
  name               = var.cluster_name
  load_balancer_type = "application"
  subnets            = aws_subnet.public[*].id
  security_groups    = [aws_security_group.alb_sg.id]
  tags               = local.common_tags
}

resource "aws_lb_target_group" "tg" {
  name     = var.cluster_name
  port     = local.http_ports[0]
  protocol = "HTTP"
  vpc_id   = aws_vpc.main.id

  health_check {
    path = "/"
    port = local.http_ports[0]
  }

  tags = local.common_tags
}

resource "aws_lb_listener" "http" {
  load_balancer_arn = aws_lb.alb.arn
  port              = 80
  protocol          = "HTTP"

  default_action {
    type             = "forward"
    target_group_arn = aws_lb_target_group.tg.arn
  }
}

# Auto Scaling Group (optional)
resource "aws_autoscaling_group" "asg" {
  count = var.enable_autoscaling ? 1 : 0

  min_size = local.min_size
  max_size = local.max_size
  vpc_zone_identifier = aws_subnet.public[*].id

  launch_template {
    id      = aws_launch_template.web.id
    version = aws_launch_template.web.latest_version
  }

  target_group_arns = [aws_lb_target_group.tg.arn]
  health_check_type = "ELB"
  health_check_grace_period = 300
}
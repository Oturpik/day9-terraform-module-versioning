output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "asg_instance_ids" {
  value = var.enable_autoscaling ? aws_autoscaling_group.asg[0].id : null
}


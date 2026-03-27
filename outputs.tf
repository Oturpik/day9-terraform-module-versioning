output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "asg_name" {
  value = aws_autoscaling_group.asg.name
}

output "asg_instance_public_ips" {
  description = "Public IPs of the ASG instances"
  value       = [for id in data.aws_instances.asg_instances.ids : data.aws_instance.asg_instance[id].public_ip]
}
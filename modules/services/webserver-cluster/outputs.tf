output "alb_dns_name" {
  value = aws_lb.alb.dns_name
}

output "instance_public_ips" {
  value = [for id in data.aws_instances.asg_instances.ids :
    data.aws_instance.asg_instance[id].public_ip
  ]
}

output "instance_ip_map" {
  value = {
    for id in data.aws_instances.asg_instances.ids :
    id => data.aws_instance.asg_instance[id].public_ip
  }
}
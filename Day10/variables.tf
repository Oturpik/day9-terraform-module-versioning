variable "cluster_name" { type = string }
variable "instance_type" { type = string }
variable "min_size" { type = number }
variable "max_size" { type = number }
variable "ami_id" { type = string }

variable "ingress_ports" {
  type    = list(number)
  default = [80]
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type = list(string)
}

# NEW
variable "environment" {
  type    = string
  default = "dev"
}

variable "enable_autoscaling" {
  type    = bool
  default = true
}
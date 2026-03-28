variable "cluster_name" {
  type = string
}

variable "ami_id" {
  type = string
}

variable "environment" {
  type    = string
  default = "dev"
  validation {
    condition     = contains(["dev", "staging", "production"], var.environment)
    error_message = "Environment must be dev, staging, or production."
  }
}

variable "vpc_cidr" {
  type    = string
  default = "10.0.0.0/16"
}

variable "public_subnet_cidrs" {
  type = list(string)
}

variable "server_ports" {
  type    = list(number)
  default = [80,8080]
}

variable "instance_type_override" {
  type    = string
  default = ""
}

variable "min_size_override" {
  type    = number
  default = 0
}

variable "max_size_override" {
  type    = number
  default = 0
}

variable "enable_autoscaling" {
  type    = bool
  default = true
}

variable "enable_detailed_monitoring" {
  type    = bool
  default = false
}

variable "create_dns_record" {
  type    = bool
  default = false
}
terraform-aws-webserver-cluster (v0.0.3)
Overview

This module provisions a scalable webserver cluster on AWS using:

Custom VPC with public subnets
Internet Gateway and routing
Application Load Balancer
Auto Scaling Group with Launch Template
Dynamic security group rules
Optional autoscaling policies

It uses Terraform loops and conditionals to support dynamic infrastructure without duplication.

Architecture
VPC spans two Availability Zones
Public subnets host EC2 instances
ALB distributes traffic across instances
ASG manages scaling and health
Security groups allow configurable ingress ports
Features
Uses for_each for stable resource creation
Uses count for optional resources
Uses for expressions for structured outputs
Supports multiple ingress ports
Environment-aware instance sizing
Versionable and reusable module design
Usage
Basic Example
module "webserver_cluster" {
  source = "github.com/your-username/terraform-aws-webserver-cluster?ref=v0.0.3"

  cluster_name        = "webservers-dev"
  vpc_cidr            = "10.0.0.0/16"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24"]

  ami_id        = "ami-xxxxxxxx"
  instance_type = "t3.micro"

  min_size = 2
  max_size = 4
}
Advanced Example
module "webserver_cluster" {
  source = "github.com/your-username/terraform-aws-webserver-cluster?ref=v0.0.3"

  cluster_name        = "webservers-prod"
  vpc_cidr            = "10.1.0.0/16"
  public_subnet_cidrs = ["10.1.1.0/24", "10.1.2.0/24"]

  ami_id        = "ami-xxxxxxxx"
  instance_type = "t3.micro"

  min_size = 4
  max_size = 10

  environment        = "production"
  enable_autoscaling = true

  ingress_ports = [80, 8080]
}
Inputs
Name	Type	Description	Required
cluster_name	string	Identifier for resources and tagging	yes
ami_id	string	AMI used for EC2 instances	yes
instance_type	string	Base instance type for non-production	yes
min_size	number	Minimum ASG size	yes
max_size	number	Maximum ASG size	yes
public_subnet_cidrs	list(string)	CIDRs for public subnets	yes
vpc_cidr	string	VPC CIDR block	no
ingress_ports	list(number)	Ports allowed into instances	no
environment	string	Environment name, affects instance size	no
enable_autoscaling	bool	Enable scaling policy	no
Defaults
vpc_cidr = 10.0.0.0/16
ingress_ports = [80]
environment = dev
enable_autoscaling = true
Outputs
Name	Description
alb_dns_name	DNS endpoint of the ALB
instance_public_ips	List of instance public IPs
instance_ip_map	Map of instance ID to public IP
Behavior
Subnets
Created using for_each
Prevents index shifting and unintended recreation
Security Groups
Rules generated dynamically from ingress_ports
Supports multiple ports without duplicating resources
Application Port
Instances listen on the first port in ingress_ports
ALB forwards traffic to that port
Autoscaling
Controlled by enable_autoscaling
Uses count to conditionally create scaling policy
Environment Logic
production → larger instance type
non-production → smaller instance type
Tagging

EC2 instances are explicitly tagged using launch template tag_specifications.

tag_specifications {
  resource_type = "instance"

  tags = {
    Environment = var.cluster_name
  }
}

This is required for:

Data sources
Observability
Cost allocation
Versioning Strategy

Always pin module versions:

source = "github.com/your-username/terraform-aws-webserver-cluster?ref=v0.0.3"
Why
Prevents unexpected infrastructure drift
Ensures reproducible deployments
Allows controlled rollout across environments
Deployment
terraform init
terraform plan
terraform apply
Validation

After apply:

Access ALB DNS in browser
Confirm HTTP response
Check instances are healthy in target group
Destroy
terraform destroy
Common Issues
Empty instance outputs

Cause:

Missing instance tags

Fix:

Ensure launch template includes tag_specifications
502 Bad Gateway

Cause:

Application not running
Wrong port
Health check failure

Fix:

Verify user data
Verify security group ports
Confirm instance responds on target port
Subnet or routing issues

Cause:

CIDR mismatch
Incorrect route table association

Fix:

Ensure subnet CIDRs fall within VPC range
Confirm route to Internet Gateway exists
Design Decisions
for_each over count

Used for:

subnets
route associations
security group rules

Reason:

stable resource identity
avoids destructive updates
count usage

Used only for:

optional resources

Reason:

simple boolean toggling
for expressions

Used in outputs to transform:

instance list → structured map
Limitations
Public-only architecture
No HTTPS support
No private subnets or NAT
Single application port used internally
Future Improvements
Private subnets and NAT Gateway
HTTPS listener with ACM
Metrics-based autoscaling policies
Blue/green deployment support
Multi-region capability
Maintainer Notes
Avoid mixing count and for_each on the same resource
Always use values() when referencing for_each resources as lists
Keep conditional logic inside locals for readability
variable "vpc" {
    description = "VPC from the vpc module"
}

variable "public-subnet" {
    description = "Public Subnets from the vpc module"
}

variable "asg" {
    description = "ASG from the ec2 module"
}

variable "name" {
    description = "Environment name"
}

variable "load-balancer" {
    description = "Create a load balancer (0 = no LB)"
}
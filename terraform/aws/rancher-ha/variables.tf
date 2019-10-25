variable "region" {
    description = "Region for the VPC"
    default = "us-west-2"
}

variable "name" {
    description = "Environment name"
    default = "rancher-lab"
}

variable "key-name" {
    description = "AWS SSH keypair name"
    default = "admin"
}

variable "admin-ip" {
    description = "Public IP in CIDR form of Admin accessing the cluster"
    default = "0.0.0.0/0"
}

variable "instance-type" {
    description = "EC2 instance type to launch"
    default = "t3a.medium"
}

variable "nodes" {
    description = "Number of rancher nodes to launch"
    default = 3
}

variable "max-nodes" {
    description = "Number of rancher nodes to launch"
    default = 4
}

variable "load-balancer" {
    description = "Create a load balancer (0 = no LB)"
    default = 1
}

variable "vpc-cidr" {
    description = "Base CIDR for the VPC - forms a /16"
    default = "10.99"
}

variable "userdata" {
    description = "UserData to launch instances"
    default = <<EOT
#!/bin/bash
apt update; apt install docker.io -y
usermod -G docker ubuntu
EOT
}

variable "vpc" {
    description = "VPC ID to create the resources"
}

variable "public-subnet" {
    description = "Subnets to create the resources in"
}
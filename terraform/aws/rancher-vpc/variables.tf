variable "region" {
    description = "Region for the VPC"
    default = "us-west-2"
}

variable "name" {
    description = "Environment name"
    default = "rancher-lab"
}

variable "vpc-cidr" {
    description = "Base CIDR for the VPC - forms a /16"
    default = "10.99"
}
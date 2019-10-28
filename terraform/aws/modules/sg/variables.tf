variable "vpc" {
    description = "VPC from the vpc module"
}

variable "name" {
    description = "Environment name"
}

variable "admin-ip" {
    description = "Public IP in CIDR form of Admin accessing the cluster"
}

variable "vpc-cidr" {
    description = "VPC CIDR"
}
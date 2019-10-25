variable "cluster-sg" {
    description = "Cluster SG from the sg module"
}

variable "admin-sg" {
    description = "Admin SG from the sg module"
}

variable "public-subnet" {
    description = "Public Subnets from the vpc module"
}

variable "name" {
    description = "Environment name"
}

variable "userdata" {
    description = "UserData to launch instances with"
}

variable "instance-type" {
    description = "Instance type"
}

variable "key-name" {
    description = "SSH key to config instances with"
}

variable "nodes" {
    description = "Desired count of the ASG"
}

variable "max-nodes" {
    description = "Max instances in the ASG"
}
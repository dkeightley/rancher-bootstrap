resource "aws_security_group" "admin-sg" {
    name_prefix = "${var.name}-"
    description = " ${var.name} - Admin SG - Allow incoming connections from IP Address"
    vpc_id = "${var.vpc}"

    ingress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["${var.admin-ip}"]
    }
    egress {
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.name}-admin-sg"
    }
}

resource "aws_security_group" "cluster-sg" {
    name_prefix = "${var.name}-"
    description = "${var.name} - Rancher Server SG - Allow incoming HTTP and all nodes to communicate"
    vpc_id = "${var.vpc}"

    ingress {  # Allow 80 via an NLB
        from_port = 80
        to_port = 80
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {  # Allow 443 via an NLB
        from_port = 443
        to_port = 443
        protocol = "tcp"
        cidr_blocks = ["0.0.0.0/0"]
    }
    ingress {  # Allow all from within the VPC
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["${var.vpc-cidr}.0.0/16"]
    }    
    egress {  # Allow all egress traffic
        from_port = 0
        to_port = 0
        protocol = "-1"
        cidr_blocks = ["0.0.0.0/0"]
    }

    tags = {
        Name = "${var.name}-cluster-sg"
        "kubernetes.io/cluster/${var.name}" = "owned"
    }
}

output "cluster-sg" {
    value = "${aws_security_group.cluster-sg.id}"
}

output "admin-sg" {
    value = "${aws_security_group.admin-sg.id}"
}
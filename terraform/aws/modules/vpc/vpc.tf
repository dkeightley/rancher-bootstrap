data "aws_availability_zones" "available" {
    state = "available"
}

resource "aws_vpc" "vpc" {
    cidr_block = "${var.vpc-cidr}.0.0/16"
    enable_dns_hostnames = true

    tags = {
        Name = "${var.name}-vpc"
    }
}

resource "aws_internet_gateway" "vpc-igw" {
    vpc_id = "${aws_vpc.vpc.id}"
}

resource "aws_route_table" "public-rtb" {
    vpc_id = "${aws_vpc.vpc.id}"

    route {
        cidr_block = "0.0.0.0/0"
        gateway_id = "${aws_internet_gateway.vpc-igw.id}"
    }

    tags = {
        Name = "${var.name}-public-rtb"
    }
}

/*
Public Subnets
*/

resource "aws_subnet" "public-subnet" {
    count = "${length(data.aws_availability_zones.available.names)}"
    vpc_id = "${aws_vpc.vpc.id}"
    map_public_ip_on_launch = true
    cidr_block = "${var.vpc-cidr}.${10+count.index}.0/24"
    availability_zone = "${data.aws_availability_zones.available.names[count.index]}"

    tags = {
        Name = "${var.name}-public-${data.aws_availability_zones.available.names[count.index]}"
    }
}

resource "aws_route_table_association" "public-rtb-assc" {
    count = "${length(data.aws_availability_zones.available.names)}"
    subnet_id = "${aws_subnet.public-subnet.*.id[count.index]}"
    route_table_id = "${aws_route_table.public-rtb.id}"
}

output "vpc" {
    value = "${aws_vpc.vpc.id}"
}

output "public-subnet" {
    value = "${aws_subnet.public-subnet.*.id}"
}
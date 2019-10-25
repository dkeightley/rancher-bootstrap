provider "aws" {
  region = "${var.region}"
}

module "vpc" {
  source = "../modules/vpc"
  vpc-cidr = "${var.vpc-cidr}"
  name = "${var.name}"
}

output "vpc" {
  value = "${module.vpc.vpc}"
}

output "public-subnet" {
  value = "${module.vpc.public-subnet}"
}
provider "aws" {
  region = "${var.region}"
}

module "sg" {
  source = "../modules/sg"
  vpc = "${var.vpc}"
  name = "${var.name}"
  admin-ip = "${var.admin-ip}"
  vpc-cidr = "${var.vpc-cidr}"
}

module "ec2" {
  source = "../modules/ec2"
  cluster-sg = "${module.sg.cluster-sg}"
  admin-sg = "${module.sg.admin-sg}"
  public-subnet = "${var.public-subnet}"
  name = "${var.name}-rke"
  userdata = "${var.userdata}"
  instance-type = "${var.instance-type}"
  key-name = "${var.key-name}"
  nodes = "${var.nodes}"
  max-nodes = "${var.max-nodes}"
}

output "admin-sg" {
  value = "${module.sg.admin-sg}"
}
data "aws_ami" "ubuntu" {
  most_recent = true

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-bionic-18.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

    owners = ["099720109477"] # Canonical
}

resource "aws_launch_configuration" "launchconfig" {
  image_id        = "${data.aws_ami.ubuntu.id}"
  instance_type   = "${var.instance-type}"
  key_name        = "${var.key-name}"
  name_prefix     = "${var.name}-"
  security_groups = ["${var.cluster-sg}","${var.admin-sg}"]
  user_data       = "${var.userdata}"

  root_block_device {
    volume_size           = 20
    volume_type           = "gp2"
    delete_on_termination = true
  }

  lifecycle {
    create_before_destroy = true
  }
}

  resource "aws_autoscaling_group" "asg" {
  launch_configuration = "${aws_launch_configuration.launchconfig.name}"
  name_prefix          = "${var.name}-"
  max_size             = "${var.max-nodes}"
  min_size             = 0
  desired_capacity     = "${var.nodes}"
  vpc_zone_identifier  = "${var.public-subnet}"

  lifecycle {
    create_before_destroy = true
  }
  
  tags = [
      {
        key                 = "Name"
        value               = "${var.name}-asg"
        propagate_at_launch = true
      },
      {
        key                 = "kubernetes.io/cluster/${var.name}"
        value               = "owned"
        propagate_at_launch = true
      }
  ]
}

output "asg" {
    value = "${aws_autoscaling_group.asg}"
}
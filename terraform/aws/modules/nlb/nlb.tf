resource "aws_lb" "nlb" {
  count                = "${var.load-balancer}"
  name                 = "${var.name}"
  internal             = false
  load_balancer_type   = "network"
  subnets              = "${var.public-subnet}"
 
  tags = {
    Name = "${var.name}-nlb"
  }
}

resource "aws_lb_target_group" "nlb-443-tg" {
  count                = "${var.load-balancer}"
  name                 = "${var.name}-443"
  port                 = 443
  protocol             = "TCP"
  vpc_id               = "${var.vpc}"
  target_type          = "instance"
  deregistration_delay = 10

  health_check {
    healthy_threshold  = 3
    interval           = 10
  }  
}

resource "aws_lb_target_group" "nlb-80-tg" {
  count                = "${var.load-balancer}"
  name                 = "${var.name}-80"
  port                 = 80
  protocol             = "TCP"
  vpc_id               = "${var.vpc}"
  target_type          = "instance"
  deregistration_delay = 10

  health_check {
    healthy_threshold  = 3
    interval           = 10
  }
}

resource "aws_lb_listener" "nlb-listener-443" {
  count                = "${var.load-balancer}"
  load_balancer_arn    = "${aws_lb.nlb[0].arn}"
  port                 = "443"
  protocol             = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.nlb-443-tg[0].arn}"
  }
}

resource "aws_lb_listener" "nlb-listener-80" {
  count                = "${var.load-balancer}"
  load_balancer_arn    = "${aws_lb.nlb[0].arn}"
  port                 = "80"
  protocol             = "TCP"

  default_action {
    type             = "forward"
    target_group_arn = "${aws_lb_target_group.nlb-80-tg[0].arn}"
  }
}

resource "aws_autoscaling_attachment" "nlb-443-attachment" {
  count                  = "${var.load-balancer}"
  autoscaling_group_name = "${var.asg.id}"
  alb_target_group_arn   = "${aws_lb_target_group.nlb-443-tg[0].arn}"
}

resource "aws_autoscaling_attachment" "nlb-80-attachment" {
  count                  = "${var.load-balancer}"
  autoscaling_group_name = "${var.asg.id}"
  alb_target_group_arn   = "${aws_lb_target_group.nlb-80-tg[0].arn}"
}

output "nlb" {
    value = "${aws_lb.nlb}"
}

output "nlb-dns-name" {
    value = "${aws_lb.nlb[0].dns_name}"
}
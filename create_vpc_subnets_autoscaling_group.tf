provider "aws" {
  region = "${var.aws_region}"
}
resource "aws_vpc" "testVPC" {
  cidr_block = "${var.vpc_cidr-block}"
  tags = {
    Name = "${var.vpc_tag}"
  }
}
resource "aws_internet_gateway" "igw1" {
  vpc_id = "${aws_vpc.testVPC.id}"
}
resource "aws_subnet" "pub" {
  vpc_id                  = "${aws_vpc.testVPC.id}"
  count                   = "${length(var.public_subnet_cidr)}"
  availability_zone       = "${var.availability_zones[count.index]}"
  cidr_block              = "${var.public_subnet_cidr[count.index]}"
  map_public_ip_on_launch = "true"
  tags = {
    Name = "pubsubnet-${count.index + 1}"
  }
}
resource "aws_subnet" "prv" {
  vpc_id            = "${aws_vpc.testVPC.id}"
  count             = "${length(var.private_subnet_cidr)}"
  availability_zone = "${var.availability_zones[count.index]}"
  cidr_block        = "${var.private_subnet_cidr[count.index]}"
  tags = {
    Name = "prvsubnet-${count.index + 1}"
  }
}
resource "aws_eip" "nat" {
  vpc = true
}
resource "aws_nat_gateway" "ngw1" {
  subnet_id     = "${aws_subnet.pub[1].id}"
  allocation_id = "${aws_eip.nat.id}"
  tags = {
    Name = "ngw1"
  }
}
resource "aws_route_table" "pub-rtb" {
  vpc_id = "${aws_vpc.testVPC.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_internet_gateway.igw1.id}"
  }
  tags = {
    Name = "pub-rtb"
  }
}
resource "aws_route_table" "prv-rtb" {
  vpc_id = "${aws_vpc.testVPC.id}"
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = "${aws_nat_gateway.ngw1.id}"
  }
  tags = {
    Name = "prv-rtb"
  }
}
resource "aws_route_table_association" "a1" {
  count          = "${length(aws_subnet.prv)}"
  route_table_id = "${aws_route_table.prv-rtb.id}"
  subnet_id      = "${aws_subnet.prv[count.index].id}"
}
resource "aws_route_table_association" "a2" {
  route_table_id = "${aws_route_table.pub-rtb.id}"
  count          = "${length(aws_subnet.pub)}"
  subnet_id      = "${aws_subnet.pub[count.index].id}"
}
resource "aws_security_group" "terraform-SG" {
  name        = "terraform-SG"
  description = "Allow web traffic"
  vpc_id      = "${aws_vpc.testVPC.id}"
  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
  egress {
    from_port   = 0
    protocol    = "-1"
    to_port     = 0
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = {
    Name = "terraform-SG"
  }
}
resource "aws_launch_configuration" "lcf1" {
  name                 = "terraform-lcf1"
  image_id             = "${lookup(var.amis, var.aws_region)}"
  instance_type        = "${var.instance_type}"
  iam_instance_profile = "ec2_cloudwatch"
  key_name             = "${var.launch_key}"
  security_groups      = ["${aws_security_group.terraform-SG.id}"]
  user_data            = "${file("get_httpd.bash")}"
}
resource "aws_autoscaling_group" "testASG" {
  name                 = "testASG"
  max_size             = 6
  min_size             = 3
  launch_configuration = "${aws_launch_configuration.lcf1.id}"
  vpc_zone_identifier  = flatten(["${aws_subnet.pub[*].id}"])
  tag {
    key                 = "Env"
    value               = "test"
    propagate_at_launch = true
  }
}
resource "aws_security_group" "elbSG" {
  name        = "elbSG"
  vpc_id      = "${aws_vpc.testVPC.id}"
  description = "SG for ELB"
  ingress {
    from_port   = 80
    protocol    = "tcp"
    to_port     = 80
    cidr_blocks = ["0.0.0.0/0"]
  }
}
resource "aws_elb" "ELB1" {
  name    = "terraform-elb"
  subnets = flatten(["${aws_subnet.pub[*].id}"])
  access_logs {
    bucket   = "jawad-elb-test"
    interval = 60
  }
  security_groups = ["${aws_security_group.terraform-SG.id}"]
  listener {
    instance_port     = 80
    instance_protocol = "http"
    lb_port           = 80
    lb_protocol       = "http"
  }
  health_check {
    healthy_threshold   = 2
    unhealthy_threshold = 3
    timeout             = 30
    target              = "HTTP:80/"
    interval            = 40
  }
}
resource "aws_autoscaling_attachment" "asg_attachment_test" {
  autoscaling_group_name = "${aws_autoscaling_group.testASG.id}"
  elb                    = "${aws_elb.ELB1.id}"
}
resource "aws_autoscaling_notification" "notify" {
  group_names = ["${aws_autoscaling_group.testASG.name}"]
  notifications = [
    "autoscaling:EC2_INSTANCE_LAUNCH",
    "autoscaling:EC2_INSTANCE_TERMINATE",
    "autoscaling:EC2_INSTANCE_LAUNCH_ERROR",
    "autoscaling:EC2_INSTANCE_TERMINATE_ERROR"
  ]
  topic_arn = "arn:aws:sns:us-east-1:319144912582:JAWS"
}

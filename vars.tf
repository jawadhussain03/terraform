variable "aws_region" {
  default = "us-east-1"
}
variable "availability_zones" {
  type    = "list"
  default = ["us-east-1a", "us-east-1b", "us-east-1c"]
}
variable "vpc_cidr-block" {
  default = "10.0.0.0/16"
}
variable "vpc_tag" {
  default = "testVPC"
}
variable "private_subnet_cidr" {
  type    = "list"
  default = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
}
variable "public_subnet_cidr" {
  type    = "list"
  default = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
}
variable "amis" {
  type = "map"
  default = {
    "us-east-1"  = "ami-0b69ea66ff7391e80"
    "ap-south-1" = "ami-0cb0e70f44e1a4bb5"
  }
}
variable "instance_type" {
  default = "t2.micro"
}
variable "iam_policy" {
  default = "ec2_cloudwatch"
}
variable "security_group" {
  default = "launch-wizard-1"
}
variable "launch_key" {
  default = "jawad_hp"
}
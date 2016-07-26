variable "keyname" {
  default = "bootstrap"
}

provider "aws" {
  access_key = "${replace("${file("~/.terraform/aws_sbp_access_key")}", "\n", "")}"
  secret_key = "${replace("${file("~/.terraform/aws_sbp_secret_key")}", "\n", "")}"
  region = "eu-west-1"
}

variable "discovery_token" { }

variable "avail_zones" {
  default = {
    "subnet0" = "eu-west-1a"
    "subnet1" = "eu-west-1b"
    "subnet2" = "eu-west-1c"
  }
}

# Change this if you'd like your token to be a bit more secure
variable "auth" {
  default = {
    user = "admin"
    token = "changeme"
  }
}

# This should be your office or VPN IP address, for the firewall
variable "source_cidr" {
  default = "195.66.90.0/24"
}

variable "publicdnszone" { default = "Z2C2SU2XH6V2S3" }

variable "clustername" {}

variable "counts" {
  default = {
    "vpcs" = "1"
    "subnets" = "3"
    "workers" = "3"
    "master" = "3"
  }
}

variable "aws_region" {
  description = "AWS region to launch servers"
  default = "eu-west-1"
}

# master settings
variable "master-ami" {
  description = "CoreOS-stable-1010.5.0"
  default = "ami-706cfd03"
}

variable "master-instance-type" {
  default = "m3.large"
}

variable "etcd-instance-type" {
  default = "t1.micro"
}

# worker settings
variable "worker-ami" {
  description = "CoreOS-stable-1068.6.0"
  default = "ami-7292f401"
}

variable "worker-instance-type" {
  default = "t2.small"
}

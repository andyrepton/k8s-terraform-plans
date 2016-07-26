# ══════════════════════════
#  k8s VPC and Network
# ══════════════════════════

# Create a VPC to launch our instances into
resource "aws_vpc" "vpc" {
  count = "${lookup(var.counts, "vpcs")}"
  cidr_block = "10.${count.index}.0.0/16"
  tags {
    Name = "${var.clustername}_k8s_vpc"
  }
  enable_dns_hostnames = true
  enable_dns_support = true
}

resource "aws_route53_zone" "vpc" {
  count = "${lookup(var.counts, "vpcs")}"
  name = "${var.clustername}.aws.internal"
  vpc_id = "${element(aws_vpc.vpc.*.id, count.index)}"
}

# Create an internet gateway to give our VPC access to the outside world
resource "aws_internet_gateway" "ig" {
  vpc_id = "${aws_vpc.vpc.id}"
  tags {
    Name = "${var.clustername}_k8s_ig"
  }
}

# Grant the VPC internet access on its main route table
resource "aws_route" "ia" {
  route_table_id         = "${aws_vpc.vpc.main_route_table_id}"
  destination_cidr_block = "0.0.0.0/0"
  gateway_id             = "${aws_internet_gateway.ig.id}"
}

# Create a subnet to launch our instances into
resource "aws_subnet" "subnet" {
  count                   = "${lookup(var.counts, "subnets")}"
  vpc_id                  = "${aws_vpc.vpc.id}"
  cidr_block              = "10.0.${count.index + 1}.0/24"
  availability_zone       = "${lookup(var.avail_zones, "subnet${count.index % lookup(var.counts, "subnets")}")}"
  map_public_ip_on_launch = false
  tags {
    Name = "${var.clustername}_k8s_net${count.index + 1}"
  }
}

# Our default security group to access
# the instances over SSH and HTTP
resource "aws_security_group" "sg" {
  name        = "${var.clustername}_k8s_sg"
  description = "${var.clustername} K8S security group"
  vpc_id      = "${aws_vpc.vpc.id}"

  # SSH access from MCinfra
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["${var.source_cidr}"]
  }
  
  ingress {
    from_port   = 8080
    to_port     = 8080
    protocol    = "tcp"
    cidr_blocks = ["${var.source_cidr}"]
  }

  ingress {
    from_port   = 6443
    to_port     = 6443
    protocol    = "tcp"
    cidr_blocks = ["${var.source_cidr}"]
  }

  ingress {
    from_port   = 0
    to_port     = 0
    protocol    = -1
    cidr_blocks = ["10.0.0.0/8"]
  }

  # outbound internet access
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  
}

output "addresses" {
  value = "Master IP addresses are ${join(", ", aws_instance.master.*.public_ip)} and worker IP addresses are ${join(", ", aws_instance.worker.*.public_ip)}"
}

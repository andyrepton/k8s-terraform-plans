# ════════════════════════════════════
#  wfsk8s  |  Kubernetes Master Server
# ════════════════════════════════════

resource "template_file" "master-config" {
  template = "${file("master.yaml.tpl")}"
  vars {
    clustername = "${var.clustername}"
    country = "${lookup(var.certificate_info, "country")}"
    city = "${lookup(var.certificate_info, "city")}"
    state = "${lookup(var.certificate_info, "state")}"
    usertoken = "${lookup(var.auth, "token")}"
    user = "${lookup(var.auth, "user")}"
    kube-apiserver-binary = "${lookup(var.binaries, "kube-apiserver")}"
    kube-controller-manager-binary = "${lookup(var.binaries, "kube-controller-manager")}"
    kube-scheduler-binary = "${lookup(var.binaries, "kube-scheduler")}"
  }
}
  
resource "aws_instance" "master" {
  count                       = "${lookup(var.counts, "master")}"
  ami                         = "${var.master-ami}"
  instance_type               = "${var.master-instance-type}"
  tags {
      Name                    = "${var.clustername}k8s-master${count.index+1}"
  }
  subnet_id                   = "${element(aws_subnet.subnet.*.id, count.index)}"
  user_data                   = "${template_file.master-config.rendered}"
  key_name                    = "${var.keyname}"
  vpc_security_group_ids      = ["${aws_security_group.sg.id}"]
  associate_public_ip_address = true
  iam_instance_profile        = "${aws_iam_instance_profile.master_instance_profile.id}"
}

resource "aws_route53_record" "master" {
   count = "${lookup(var.counts, "master")}"
   zone_id = "${element(aws_route53_zone.vpc.*.zone_id, count.index)}"
   name = "${var.clustername}master${count.index}"
   type = "A"
   ttl = "300"
   records = ["${element(aws_instance.master.*.private_ip, count.index)}"]
}

resource "aws_iam_instance_profile" "master_instance_profile" {
    name = "${var.clustername}_k8s_master"
    roles = ["${aws_iam_role.master_role.name}"]
}

resource "aws_iam_role" "master_role" {
  name = "${var.clustername}_k8s_master_role"
  path = "/"
  assume_role_policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Action": "sts:AssumeRole",
            "Principal": {"AWS": "*"},
            "Effect": "Allow",
            "Sid": ""
        }
    ]
}
EOF
}

resource "aws_iam_role_policy" "master_role_policy" {
    name = "${var.clustername}_k8s_master_policy"
    role = "${aws_iam_role.master_role.id}"
    policy = <<EOF
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "ec2:*"
            ],
            "Resource": [
                "*"
            ]
        },
        {
            "Effect": "Allow",
            "Action": [
                "elasticloadbalancing:*"
            ],
            "Resource": [
                "*"
            ]
        }
    ]
}
EOF
}

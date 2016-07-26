# ════════════════════════════════════
#  k8s POC |  Kubernetes Workers
# ════════════════════════════════════

resource "template_file" "worker-config" {
  template = "${file("worker.yaml.tpl")}"
  vars {
    master1IP = "${aws_instance.master.0.private_ip}"
    clustername = "${var.clustername}"
    kube-kubelet-binary = "${lookup(var.binaries, "kube-kubelet")}"
    kube-proxy-binary = "${lookup(var.binaries, "kube-proxy")}"
  }
}

resource "aws_instance" "worker" {
  count                       = "${lookup(var.counts, "workers")}"
  ami                         = "${var.worker-ami}"
  instance_type               = "${var.worker-instance-type}"
  tags {
      Name                    = "${var.clustername}k8s_worker${count.index}"
  }
  subnet_id                   = "${element(aws_subnet.subnet.*.id, count.index)}"
  associate_public_ip_address = true
  user_data                   = "${template_file.worker-config.rendered}"
  key_name                    = "${var.keyname}"
  vpc_security_group_ids      = ["${aws_security_group.sg.id}"]
  iam_instance_profile        = "${aws_iam_instance_profile.worker_instance_profile.id}"
}

resource "aws_ebs_volume" "worker_disk" {
    count = "${lookup(var.counts, "workers")}"
    availability_zone = "${element(aws_subnet.subnet.*.availability_zone, count.index)}"
    size = 30
    tags {
        Name = "${var.clustername}k8s_worker${count.index}"
    }
}

resource "aws_volume_attachment" "ebs_attach" {
  count = "${lookup(var.counts, "workers")}"
  device_name = "/dev/sdf"
  volume_id = "${element(aws_ebs_volume.worker_disk.*.id, count.index)}"
  instance_id = "${element(aws_instance.worker.*.id, count.index)}"
  force_detach = true
}

resource "aws_iam_instance_profile" "worker_instance_profile" {
    name = "${var.clustername}_kubernetes_workers"
    roles = ["${aws_iam_role.worker_role.name}"]
}

resource "aws_iam_role" "worker_role" {
  name = "${var.clustername}_kubernetes_worker_role"
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

resource "aws_iam_role_policy" "worker_role_policy" {
    name = "${var.clustername}_kubernetes_worker_policy"
    role = "${aws_iam_role.worker_role.id}"
    policy = <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": "ec2:Describe*",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:AttachVolume",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": "ec2:DetachVolume",
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:GetRepositoryPolicy",
        "ecr:DescribeRepositories",
        "ecr:ListImages",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
EOF
}

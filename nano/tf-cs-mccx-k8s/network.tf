resource "cloudstack_vpc" "vpc" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "vpc")}"
  name = "SBP_VPC_${var.clustername}${count.index+1}"
  cidr = "10.100.${count.index}.0/24"
  vpc_offering = "${lookup(var.offerings, "vpc${count.index}")}"
  zone = "${lookup(var.cs_zones, "vpc")}"
}

resource "cloudstack_network" "network" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "network")}"
  name = "SBP_NET_${var.clustername}${count.index+1}"
  display_text = "k8s_${var.clustername}${count.index+1}"
  cidr = "10.100.${count.index}.0/26"
  network_offering = "${lookup(var.offerings, "network")}"
  zone = "${lookup(var.cs_zones, "network")}"
  vpc_id = "${element(cloudstack_vpc.vpc.*.id, count.index)}"
  acl_id = "${element(cloudstack_network_acl.acl.*.id, count.index)}"
}

resource "cloudstack_network_acl" "acl" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "vpc")}"
  name = "k8s_${var.clustername}-acl-${count.index+1}"
  vpc_id = "${element(cloudstack_vpc.vpc.*.id, count.index)}"
}

resource "cloudstack_network_acl_rule" "acl-rule" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "vpc")}"
  acl_id = "${element(cloudstack_network_acl.acl.*.id, count.index)}"

  rule {
    source_cidr = "${var.source_cidr_1}"
    protocol = "all"
    action = "allow"
    traffic_type = "ingress"
  }

  rule {
    source_cidr = "${var.source_cidr_2}"
    protocol = "all"
    action = "allow"
    traffic_type = "ingress"
  }
}

resource "cloudstack_ipaddress" "worker_public_ip" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "worker")}"
  vpc = "${element(cloudstack_vpc.vpc.*.id, count.index)}"
  depends_on = ["cloudstack_instance.kube-worker"]
}
resource "cloudstack_ipaddress" "master_public_ip" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "master")}"
  vpc = "${element(cloudstack_vpc.vpc.*.id, count.index)}"
  depends_on = ["cloudstack_instance.kube-master"]
}

resource "cloudstack_port_forward" "master" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "master")}"
  ipaddress = "${element(cloudstack_ipaddress.master_public_ip.*.id, count.index)}"

  forward {
    protocol = "tcp"
    private_port = "22"
    public_port = "22"
    virtual_machine_id = "${element(cloudstack_instance.kube-master.*.id, count.index)}"
  }
  forward {
    protocol = "tcp"
    private_port = "8080"
    public_port = "8080"
    virtual_machine_id = "${element(cloudstack_instance.kube-master.*.id, count.index)}"
  }
  forward {
    protocol = "tcp"
    private_port = "6443"
    public_port = "6443"
    virtual_machine_id = "${element(cloudstack_instance.kube-master.*.id, count.index)}"
  }
}

resource "cloudstack_static_nat" "worker" {
  count = "${lookup(var.counts, "worker")}"
  provider = "cloudstack.nl2"
  ip_address_id = "${element(cloudstack_ipaddress.worker_public_ip.*.id, count.index)}"
  network_id = "${element(cloudstack_network.network.*.id, count.index)}"
  depends_on = ["cloudstack_instance.kube-worker"]
  virtual_machine_id = "${element(cloudstack_instance.kube-worker.*.id, count.index)}"
}

output "addresses" {
  value = "Master IP addresses are ${join(", ", cloudstack_ipaddress.master_public_ip.*.ip_address)} and worker IP addresses are ${join(", ", cloudstack_ipaddress.worker_public_ip.*.ip_address)}" 
}

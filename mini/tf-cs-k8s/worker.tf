resource "template_file" "node-config" {
    count = "${lookup(var.counts, "worker")}"
    template = "${file("worker.yaml.tpl")}"
    vars {
      master1IP = "${cloudstack_instance.kube-master.0.ip_address}"
      master2IP = "${cloudstack_instance.kube-master.1.ip_address}"
      master3IP = "${cloudstack_instance.kube-master.2.ip_address}"
      custom_host_entry = "${var.custom_host_entry}"
      kube-kubelet-binary = "${lookup(var.binaries, "kube-kubelet")}"
      kube-proxy-binary = "${lookup(var.binaries, "kube-proxy")}"
    }
}

resource "cloudstack_instance" "kube-worker" {
  depends_on = ["cloudstack_instance.kube-master"]
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "worker")}"
  zone = "${lookup(var.cs_zones, "worker")}"
  service_offering = "${lookup(var.offerings, "worker")}"
  template = "${var.cs_template}"
  name = "${var.clustername}k8s-worker${count.index+1}"
  network = "${element(cloudstack_network.network.*.id, count.index)}"
  expunge = "true"
  user_data = "${element(template_file.node-config.*.rendered, count.index)}"
  keypair = "${var.keypair}"
}

resource "cloudstack_disk" "kube-worker" {
  provider = "cloudstack.nl2"
  count = "${lookup(var.counts, "worker")}"
  zone = "${lookup(var.cs_zones, "worker")}"
  name = "${var.clustername}k8s-worker${count.index+1}disk"
  disk_offering = "${lookup(var.offerings, "small_disk")}"
  attach = "true"
  virtual_machine = "${element(cloudstack_instance.kube-worker.*.id, count.index)}"
  device = "/dev/xvdf"
}

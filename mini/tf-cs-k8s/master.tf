resource "template_file" "master-config" {
    count = "${lookup(var.counts, "master")}"
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
      discovery_token = "${var.discovery_token}"
    }
}

resource "cloudstack_instance" "kube-master" {
  count = "${lookup(var.counts, "master")}"
  provider = "cloudstack.nl2"
  zone = "${lookup(var.cs_zones, "master")}"
  service_offering = "${lookup(var.offerings, "master")}"
  template = "${var.cs_template}"
  name = "${var.clustername}k8s-master${count.index+1}"
  network = "${element(cloudstack_network.network.*.id, count.index)}"
  expunge = "true"
  user_data = "${element(template_file.master-config.*.rendered, count.index)}"
  keypair = "${var.keypair}"
}

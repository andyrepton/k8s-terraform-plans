variable "clustername" {}

# Replace these with your api key/secret key/api url
provider "cloudstack" {
    api_key       =  "${replace("${file("~/.terraform/nl2_cs_mccx_api_key")}", "\n", "")}"
    secret_key    =  "${replace("${file("~/.terraform/nl2_cs_mccx_secret_key")}", "\n", "")}"
    api_url       =  "https://beta-nl2.mcc.schubergphilis.com/client/api"
    alias         =  "nl2"
}

# You will need to change these to be your CloudStack zones
variable "cs_zones" {
  default = {
    network = "BETA-NL2"
    master = "BETA-NL2"
    worker = "BETA-NL2"
    vpc = "BETA-NL2"
  }
}

# This should be your office or VPN IP address, for the firewall
variable "source_cidr" {
  default = "195.66.90.0/24"
}

# You will need to change these to match your service offerings in CloudStack
variable "offerings" {
  default = {
    master = "MCC_v2.1vCPU.4GB.SBP1"
    worker = "MCC_v2.2vCPU.8GB.SBP1"
    network = "MCC-VPC-LB"
    vpc0 = "MCC-KVM-VPC-SBP1"
    small_disk = "MCC.v1-40GB"
  }
}

# This should match a CoreOS template. If you do not have one, you can download them from here:
# http://dl.openvm.eu/cloudstack/coreos/x86_64/
variable "cs_template" {
  default = "Coreos-beta-x86_64-Community-KVM-latest"
}

# This is for the self signed certificate, change to match your location
variable "certificate_info" {
  default = {
    country = "NL"
    city = "Amsterdam"
    state = "Noord Holland"
  }
}

# Change this if you'd like your token to be a bit more secure
variable "auth" {
  default = {
    user = "admin"
    token = "changeme"
  }
}

# You need to have a keypair in CloudStack for Cloud-Config to put onto the servers.
# You can find instructions on this here: https://shankerbalan.net/blog/ssh-keys-on-cloudstack-guest-instances-using-cloud-init/
variable "keypair" {
  default = "deployment"
}

# Put your registry in here if you have one, allowing you to push/pull images
# ToDO: remove this and add through k8s
variable "custom_host_entry" {
  default = "85.222.236.236 registry.services.schubergphilis.com"
}

# In case you would like to use custom binaries you've build yourself
variable "binaries" {
  default = {
    kube-apiserver = "https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-apiserver"
    kube-controller-manager = "https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-controller-manager"
    kube-scheduler = "https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-scheduler"
    kube-proxy = "https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-proxy"
    kube-kubelet = "https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kubelet"
  }
}

variable "counts" {
  default = {
    vpc = "1"
    network = "1"
    master = "1"
    worker = "1"
  }
}

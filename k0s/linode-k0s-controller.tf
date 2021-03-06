provider "linode" {
  token = var.linode_token
}

resource "linode_instance" "k0s-controller" {
  image           = "linode/alpine3.15"
  label           = "k0s-controller-2021-12-06"
  group           = "Terraform"
  region          = "us-central"
  type            = "g6-nanode-1"
  authorized_keys = [var.ssh_authorized_key]
  root_pass       = var.root_password
}

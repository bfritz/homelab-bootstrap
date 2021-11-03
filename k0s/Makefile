K0SCTL_VER := 0.11.4
K0SCTL_URL := https://github.com/k0sproject/k0sctl/releases/download/v$(K0SCTL_VER)/k0sctl-linux-x64

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir := $(dir $(mkfile_path))

.PHONY: all add_controller_host provision_controller ssh_controller install_k0sctl build_cluster

all:

add_controller_host: authorized_key.tf
	terraform init
	terraform plan -out tf.plan
	sleep 15   # time to review plan and hit ctrl-c if necessary :)
	terraform apply tf.plan

# Use `authorized_key.tf.example` as a guide to create your own `authorized_key.tf` file.
# If you have a real `authorized_key.tf` file in place, the copy below will not run.
authorized_key.tf:
	cp -i authorized_key.tf.example authorized_key.tf

provision_controller:
	# sed is hack to allow traffic from host with Makefile when no management hosts are configured
	cat provision.sh \
		| sed "s/^MANAGEMENT_HOSTS='\[\]'/MANAGEMENT_HOSTS='[\"$$(curl -s https://ifconfig.me)\"]'/" \
		| ssh root@$(shell cd $(mkfile_dir); ./tf_controller_ip.sh) dd of=/tmp/provision.sh
	ssh root@$(shell cd $(mkfile_dir); ./tf_controller_ip.sh) sh -x /tmp/provision.sh

ssh_controller:
	ssh root@$(shell cd $(mkfile_dir); ./tf_controller_ip.sh)

install_k0sctl:
	@[ -e /usr/local/bin/k0sctl ] || (curl -o /tmp/k0sctl -Lf $(K0SCTL_URL) && chmod 0755 /tmp/k0sctl && sudo mv /tmp/k0sctl /usr/local/bin/ && k0sctl version)

build_cluster: cluster.yaml
	k0sctl apply --disable-telemetry --config cluster.yaml
	$(info Saving kubeconfig file to cluster_kubeconf.yaml ...)
	k0sctl kubeconfig --disable-telemetry --config cluster.yaml > cluster_kubeconf.yaml

cluster.yaml: cluster.yaml.in
	K0S_CONTROLLER_IP=$(shell cd $(mkfile_dir); ./tf_controller_ip.sh) \
	    gomplate -f cluster.yaml.in > cluster.yaml
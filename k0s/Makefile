ARGOCD_VER := 2.3.2
ARGOCD_CLI_URL := https://github.com/argoproj/argo-cd/releases/download/v$(ARGOCD_VER)/argocd-linux-amd64

K0SCTL_VER := 0.12.2
K0SCTL_URL := https://github.com/k0sproject/k0sctl/releases/download/v$(K0SCTL_VER)/k0sctl-linux-x64

mkfile_path := $(abspath $(lastword $(MAKEFILE_LIST)))
mkfile_dir := $(dir $(mkfile_path))

kubeconfig := cluster_kubeconf.yaml

.PHONY: \
	all \
	add_controller_host \
	provision_controller \
	ssh_controller \
	install_k0sctl \
	build_cluster \
	argocd_cli_install \
	argocd_cli_login \
	argocd_find_initial_admin_password \
	argocd_find_service_name \
	argocd_launch_apps \
	__end

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
	$(info Saving kubeconfig file to $(kubeconfig) ...)
	k0sctl kubeconfig --disable-telemetry --config cluster.yaml > $(kubeconfig)

cluster.yaml: cluster.yaml.in
	K0S_CONTROLLER_IP=$(shell cd $(mkfile_dir); ./tf_controller_ip.sh) \
	    gomplate -f cluster.yaml.in > cluster.yaml

# Argo CD targets
argocd_cli_install:
	$(info Note: You may be prompted for sudo password to save `argocd` into `/usr/local/bin/` .)
	@[ -e /usr/local/bin/argocd ] \
		|| (curl -o /tmp/argocd -Lf $(ARGOCD_CLI_URL) && chmod 0755 /tmp/argocd && sudo mv /tmp/argocd /usr/local/bin/)
	@argocd version

argocd_cli_login: argocd_find_service_name
	$(info Provide access with:)
	$(info kubectl --kubeconfig $(kubeconfig) port-forward $(ARGOCD_SVC) -n argocd 8080:443)
	argocd login localhost:8080 --insecure \
		--username admin \
		--password $(shell KUBECONFIG=$(kubeconfig) kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d)

argocd_find_initial_admin_password: argocd_find_service_name
	$(info Access UI with:)
	$(info kubectl --kubeconfig $(kubeconfig) port-forward $(ARGOCD_SVC) -n argocd 8080:443)
	$(info Initial ArgoCD admin password is:)
	@KUBECONFIG=$(kubeconfig) \
		kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d ; echo

argocd_find_service_name:
	$(eval ARGOCD_SVC := $(shell kubectl --kubeconfig $(kubeconfig) -n argocd get service -l 'app.kubernetes.io/name=argocd-server' -o name))

argocd_launch_apps:
	ssh root@$(shell cd $(mkfile_dir); ./tf_controller_ip.sh) mkdir -p /var/lib/k0s/manifests/apps \&\& curl -sLo /var/lib/k0s/manifests/apps/apps.yaml https://raw.githubusercontent.com/bfritz/homelab-apps/main/apps.yaml


__end:

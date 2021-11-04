Support files to launch [k0s] controller node in [Linode] using [Terraform].

Makefile and terraform config to provision a new Linode
[1GB "Nanode" instance] as a k0s controller node [using k0sctl] and to
join one or more `k0s-worker` instances into the cluster.

Usage:

    # optional: rm terraform.tfstate   # to have terraform ignore existing controllers
    make add_controller_host
    make provision_controller
    # optional: make install_k0sctl    # to install x86_64 copy of k0sctl on build host
    make build_cluster
    make argocd_launch_apps


[1gb "nanode" instance]: https://www.linode.com/pricing/#compute-shared
[k0s]: https://k0sproject.io/
[linode]: https://linode.com/
[terraform]: https://www.terraform.io/
[using k0sctl]: https://docs.k0sproject.io/main/k0sctl-install/

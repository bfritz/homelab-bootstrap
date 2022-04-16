profile_k0s_worker() {
    profile_standard
    profile_abbrev="k0s_worker"
    title="Alpine for k0s worker node"
    desc="Standard Alpine image ready to be provisioned as k0s worker node, likely with k0sctl.  Runs from RAM."
    arch="x86_64"
    apks="$apks chrony openssh-server findutils coreutils curl iptables nfs-utils atop"
    apkovl="genapkovl-k0s-node.sh"
}

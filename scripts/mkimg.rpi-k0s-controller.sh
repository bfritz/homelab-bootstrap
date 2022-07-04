k0s_controller_gen_usercfg() {
    cat <<-EOF
    gpu_mem=16
    dtoverlay=disable-bt
EOF
}

build_k0s_controller_usercfg() {
    k0s_controller_gen_usercfg > "${DESTDIR}"/usercfg.txt
}

section_k0s_controller_usercfg() {
    [ "$PROFILE" = "rpi_k0s_controller" ] || return 0
    build_section k0s_controller_usercfg "$( k0s_controller_gen_usercfg | checksum )"
}

profile_rpi_k0s_controller() {
    profile_rpi
    profile_abbrev="k0s_controller"
    title="Alpine for k0s controller node (RPi)"
    desc="Standard Alpine image ready to be provisioned as k0s controller node, likely with k0sctl.  Runs from RAM."
    apks="$apks chrony openssh-server findutils coreutils curl iptables nfs-utils atop"
    apkovl="genapkovl-k0s-node.sh"
}

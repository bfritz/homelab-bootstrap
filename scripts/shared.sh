#!/bin/sh -e

cleanup() {
        rm -rf "$tmp"
}

makefile() {
        OWNER="$1"
        PERMS="$2"
        FILENAME="$3"
        cat > "$FILENAME"
        chown "$OWNER" "$FILENAME"
        chmod "$PERMS" "$FILENAME"
}

rc_add() {
        mkdir -p "$tmp"/etc/runlevels/"$2"
        ln -sf /etc/init.d/"$1" "$tmp"/etc/runlevels/"$2"/"$1"
}

apk_add() {
        if [ ! -d "$tmp"/etc/apk ] ; then
                mkdir -p "$tmp"/etc/apk
        fi
        if [ ! -f "$tmp"/etc/apk/world ] ; then
                makefile root:root 0644 "$tmp"/etc/apk/world <<EOF
EOF
        fi
        for a in "$@" ; do
                if ! grep -q "$a" "$tmp"/etc/apk/world ; then
                        echo "$a" >> "$tmp"/etc/apk/world
                fi
        done
}

# if $HL_SSH_KEY_URL is set, download and drop into /root/.ssh/authorized_keys
add_ssh_key() {
    [ -d "$tmp"/root ] || mkdir --mode=0700 "$tmp"/root
    if [ -n "$HL_SSH_KEY_URL" ]; then
        mkdir --mode=0700 "$tmp"/root/.ssh

        curl --max-time 10 "$HL_SSH_KEY_URL" > "$tmp"/root/.ssh/authorized_keys
        chmod 0400 "$tmp"/root/.ssh/authorized_keys
    fi
}

install_overlays() {
    if [ -n "$HL_OVERLAY_DIR" ] && [ -d "$HL_OVERLAY_DIR" ]; then
        for T in "$HL_OVERLAY_DIR"/*.tgz; do
            if [ -e "$T" ]; then
                name="$(basename "$T")"
                echo "Extracting $name overlay..."
                tar -C "$tmp" -xzf "$T"
            fi
        done
    fi
}

tmp="$(mktemp -d)"

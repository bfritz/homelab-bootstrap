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
        for a in $@ ; do
                if [ -z "$(cat $tmp/etc/apk/world | grep $a)" ] ; then
                        echo $a >> "$tmp"/etc/apk/world
                fi
        done
}

tmp="$(mktemp -d)"

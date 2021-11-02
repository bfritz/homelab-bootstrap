#!/bin/sh

# Tested with Linode 1GB instance running Alpine 3.14.2.

set -e

# shellcheck disable=SC1091
. /etc/os-release
echo "Setting up k0s kubernetes controller node on Alpine Linux $VERSION_ID ."

setup-hostname -n k0s-controller && hostname k0s-controller

sed -i 's/http:/https:/' /etc/apk/repositories
apk update
apk upgrade
apk add awall iptables

MANAGEMENT_HOSTS='[]'

umask 0077
cat <<EOF > /etc/awall/private/vars.json
{
  "description": "Miscellaneous variables.",
  "variable": {
    "INTERNET_IF": "eth0",
    "MANAGEMENT_HOSTS": $MANAGEMENT_HOSTS
  }
}
EOF

cat <<EOF > /etc/awall/private/custom-services.json
{
  "service": {
    "kube-api": [
      { "proto": "tcp", "port": 6443 }
    ],
    "kube-konnectivity": [
      { "proto": "tcp", "port": 8132 }
    ]
  }
}
EOF

cat <<EOF > /etc/awall/fw-k0s-controller.json
{
  "description": "Firewall policy for k0s controller node.",
  "import": ["vars", "custom-services"],
  "zone": {
    "internet": {
      "iface": "\$INTERNET_IF"
    }
  },
  "policy": [
    { "in": "internet", "action": "drop" },
    { "action": "reject" }
  ]
}
EOF

cat <<EOF > /etc/awall/base.json
{
  "description": "Allow FW access to support services like DNS and NTP.",
  "filter": [
    {
      "in": "_fw",
      "out": "internet",
      "service": ["ping", "ntp", "dns", "https"],
      "action": "accept"
    }
  ]
}
EOF

cat <<EOF > /etc/awall/optional/mgmt-in.json
{
  "description": "Allow management hosts to SSH in.",
  "filter": [
    {
      "in": "internet",
      "out": "_fw",
      "service": ["ping", "ssh"],
      "action": "accept",
      "src": "\$MANAGEMENT_HOSTS"
    }
  ]
}
EOF

cat <<EOF > /etc/awall/optional/k8s.json
{
  "description": "Allow required kubernetes network traffic.",
  "filter": [
    {
      "in": "internet",
      "out": "_fw",
      "service": ["kube-api", "kube-konnectivity"],
      "action": "accept",
      "src": "\$MANAGEMENT_HOSTS"
    }
  ]
}
EOF




awall enable mgmt-in
awall enable k8s
awall activate

apk add prometheus-node-exporter

# send firewall logs to /var/log/messages
rc-update add klogd boot
rc-service klogd start

for svc in cgroups iptables ip6tables node-exporter; do
    rc-update add $svc
    rc-service $svc start
done

# keep longer history in /var/log/messages files
cat <<EOF > /etc/conf.d/syslog
# -t         Strip client-generated timestamps
# -s SIZE    Max size (KB) before rotation (default 200KB, 0=off)
# -b N       N rotated logs to keep (default 1, max 99, 0=purge)

SYSLOGD_OPTS="-t -s 512 -b 10"
EOF

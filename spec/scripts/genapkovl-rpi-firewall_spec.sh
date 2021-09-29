Describe 'genapkovl-rpi-firewall_spec.sh'
  # mock chown calls or tests will fail when not run as root
  chown() {
      true
  }

  Include ./scripts/genapkovl-rpi-firewall.sh

  Describe 'add_vlan_interface'

    It 'adds interface stanza in /etc/network/interfaces'
      Path network-interfaces="$tmp/etc/network/interfaces"
      When call add_vlan_interface 105 172.22.5
      The path network-interfaces should be exist
      The contents of file network-interfaces should include "auto eth0.105
iface eth0.105 inet static
	address 172.22.5.1
	netmask 255.255.255.0"
    End
  End

  Describe 'add_vlan_dns_and_dhcp'
    Path dnsmasq-conf-vwif="$tmp/etc/dnsmasq.d/1050_vwif.conf"
    Path dnsmasq-conf-voip="$tmp/etc/dnsmasq.d/1120_voip.conf"

    It 'should bind dnsmasq to expected interface'
      When call add_vlan_dns_and_dhcp 105 172.22.5 vwif
      The path dnsmasq-conf-vwif should be exist
      The contents of file dnsmasq-conf-vwif should include "interface=eth0.105
bind-interfaces"
    End

    It 'should enable dhcp'
      When call add_vlan_dns_and_dhcp 105 172.22.5 vwif
      The path dnsmasq-conf-vwif should be exist
      The contents of file dnsmasq-conf-vwif should include "dhcp-range=172.22.5.100,172.22.5.149,12h"
    End

    It 'should enable set ntp server dhcp option'
      When call add_vlan_dns_and_dhcp 105 172.22.5 vwif
      The path dnsmasq-conf-vwif should be exist
      The contents of file dnsmasq-conf-vwif should include "dhcp-option=42,172.22.5.1"
    End

    It 'should use static keyword when dhcp flag is off'
      When call add_vlan_dns_and_dhcp 112 172.22.12 voip 0
      The path dnsmasq-conf-voip should be exist
      The contents of file dnsmasq-conf-voip should include "dhcp-range=172.22.12.0,static"
    End
  End

  Describe 'configure_wireguard'
    Path vpn-routes="$tmp/usr/local/bin/vpn_routes"

    It 'creates /usr/local/bin/vpn_routes'
      When call configure_wireguard
      The path vpn-routes should be exist
      The path vpn-routes should be executable
    End
  End
End

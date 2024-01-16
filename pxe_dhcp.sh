#!/bin/bash

# Variables de configuration
dhcp_domain_name="test.lan"
dhcp_dns_servers="1.1.1.1, 1.0.0.1"
dhcp_subnet="192.168.1.0"
dhcp_netmask="255.255.255.0"
dhcp_range_start="192.168.1.240"
dhcp_range_end="192.168.1.250"
dhcp_routers="192.168.1.1"
dhcp_broadcast_address="192.168.1.255"
pxe_server_ip="192.168.1.14"
tftp_root="/srv/tftp"

# Variables de configuration pour IPv6
dhcp6_subnet=""
dhcp6_prefix="/64"
dhcp6_range_start="::10"
dhcp6_range_end="::100"
dhcp6_name_servers="::1"
dhcp6_domain_search="test.lan"

# Détecter l'interface réseau principale
interface=$(ip route | grep default | sed -e "s/^.*dev.//" -e "s/.proto.*//" | tr -d ' ')

# Mise à jour des paquets et installation des dépendances
sudo apt update
sudo apt install -y isc-dhcp-server tftpd-hpa syslinux pxelinux

# Configuration du serveur DHCP pour IPv4
cat <<EOF | sudo tee /etc/dhcp/dhcpd.conf
option domain-name "$dhcp_domain_name";
option domain-name-servers $dhcp_dns_servers;
default-lease-time 600;
max-lease-time 7200;
ddns-update-style none;
authoritative;
subnet $dhcp_subnet netmask $dhcp_netmask {
  range $dhcp_range_start $dhcp_range_end;
  option subnet-mask $dhcp_netmask;
  option routers $dhcp_routers;
  option broadcast-address $dhcp_broadcast_address;
  next-server $pxe_server_ip;
  filename "pxelinux.0";
}
EOF

# Configuration du serveur DHCP pour IPv6
cat <<EOF | sudo tee /etc/dhcp/dhcpd6.conf
subnet6 $dhcp6_subnet$dhcp6_prefix {
  range6 $dhcp6_range_start $dhcp6_range_end;
  option dhcp6.name-servers $dhcp6_name_servers;
  option dhcp6.domain-search "$dhcp6_domain_search";
}
EOF

# Configuration de l'interface pour isc-dhcp-server
cat <<EOF | sudo tee /etc/default/isc-dhcp-server
INTERFACESv4="$interface"
INTERFACESv6="$interface"
EOF

# Démarrage et activation du service DHCP
sudo systemctl restart isc-dhcp-server
sudo systemctl enable isc-dhcp-server

# Configuration du serveur TFTP
sudo systemctl start tftpd-hpa
sudo systemctl enable tftpd-hpa

# Préparation des fichiers PXE
sudo mkdir -p $tftp_root
sudo cp /usr/lib/PXELINUX/pxelinux.0 $tftp_root/
sudo cp /usr/lib/syslinux/modules/bios/ldlinux.c32 $tftp_root/
sudo cp /usr/lib/syslinux/modules/bios/menu.c32 $tftp_root/
sudo cp /usr/lib/syslinux/modules/bios/libutil.c32 $tftp_root/
sudo cp /usr/lib/syslinux/modules/bios/libmenu.c32 $tftp_root/

# Téléchargement des fichiers PXE Debian
sudo mkdir -p $tftp_root/debian-installer/amd64
cd $tftp_root/debian-installer/amd64
sudo wget https://deb.debian.org/debian/dists/stable/main/installer-amd64/current/images/netboot/debian-installer/amd64/linux
sudo wget https://deb.debian.org/debian/dists/stable/main/installer-amd64/current/images/netboot/debian-installer/amd64/initrd.gz

# Configuration du menu PXE
sudo mkdir -p $tftp_root/pxelinux.cfg
cat <<EOF | sudo tee $tftp_root/pxelinux.cfg/default
DEFAULT menu.c32
PROMPT 0
MENU TITLE PXE Menu
TIMEOUT 300
LABEL Debian 12 Install
  MENU LABEL ^Install Debian 12
  KERNEL debian-installer/amd64/linux
  APPEND initrd=debian-installer/amd64/initrd.gz
EOF

# Redémarrage des services pour appliquer les changements
sudo systemctl restart tftpd-hpa
sudo systemctl restart isc-dhcp-server

echo "Configuration du serveur PXE terminée."

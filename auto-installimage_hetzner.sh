#!/bin/bash
# Définir les autres variables nécessaires
HOSTNAME="rt"

# Lister les disques disponibles
echo "Liste des disques disponibles :"
lsblk -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,LABEL,MODEL

# Demander à l'utilisateur de sélectionner les disques pour le RAID 1
read -p "Entrez le nom exact du premier disque pour le RAID 1 (ex: sda, nvme0n1): " RAID_DISK1
read -p "Entrez le nom exact du second disque pour le RAID 1 (ex: sdb, nvme1n1): " RAID_DISK2

# Créer le fichier /autosetup pour installimage
AUTOSetup_FILE="/autosetup"
cat > $AUTOSetup_FILE <<EOF
DRIVE1 /dev/$RAID_DISK1
DRIVE2 /dev/$RAID_DISK2
HOSTNAME $HOSTNAME
BOOTLOADER grub
SWRAID 1
RAIDLEVEL 1
PART /boot ext3 512M
PART / ext4 all
#PART swap swap 16G
IMAGE /root/images/Debian-1202-bookworm-amd64-base.tar.gz
SSHKEYS_URL /root/.ssh/authorized_keys
EOF


# Informer l'utilisateur que le fichier de configuration est prêt
echo "Le fichier de configuration /autosetup a été créé avec les paramètres suivants :"
cat $AUTOSetup_FILE

# Lancer installimage
echo "Lancement de installimage..."
/root/.oldroot/nfs/install/installimage


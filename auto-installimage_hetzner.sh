#!/bin/bash

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Functions
show_available_images() {
    local images_path=$1
    echo -e "${GREEN}Images disponibles dans $images_path :${NC}"
    local available_images=($(ls $images_path))
    for img in "${available_images[@]}"; do
        echo " - $img"
    done
}

list_disks() {
    echo -e "${GREEN}Liste des disques disponibles :${NC}"
    local disks=($(lsblk -d -n -o NAME | grep -E '^(s|nvme)'))
    for disk in "${disks[@]}"; do
        local disk_info=$(lsblk -d -n -o NAME,SIZE,MODEL /dev/$disk)
        printf "%-8s %-8s %-20s\n" $disk_info
    done
    echo ""
}

configure_raid() {
    local disks=("$@")
    local drive_count=1
    echo "SWRAID 1" >> $AUTOSetup_FILE
    echo "RAIDLEVEL 1" >> $AUTOSetup_FILE
    for disk in "${disks[@]}"; do
        echo "DRIVE${drive_count} /dev/$disk" >> $AUTOSetup_FILE
        ((drive_count++))
    done
}

select_image() {
    local default_image=$1
    read -p "Entrez le nom de l'image souhaitée (default: $default_image): " image_chosen
    image_chosen=${image_chosen:-$default_image}
    echo $image_chosen
}

# Main Script
echo -e "${GREEN}Configuration du Serveur Hetzner${NC}"
echo "--------------------------------"

read -p "Entrez le nom d'hôte souhaité (ex: MonServeur): " HOSTNAME
echo ""

IMAGES_PATH="/root/images"
DEFAULT_IMAGE="Debian-1202-bookworm-amd64-base.tar.gz"

show_available_images $IMAGES_PATH
IMAGE_CHOSEN=$(select_image $DEFAULT_IMAGE)

disques=($(lsblk -d -n -o NAME | grep -E '^(s|nvme)'))
list_disks "${disques[@]}"

AUTOSetup_FILE="/autosetup"
cat > $AUTOSetup_FILE <<EOF
HOSTNAME $HOSTNAME
BOOTLOADER grub
EOF

# Instructions et configuration RAID ou standard
echo "Vous disposez de ${#disques[@]} disque(s)."
read -p "Voulez-vous configurer un RAID avec ces disques (o/n) ? " choix_raid
echo ""
if [[ $choix_raid == 'o' ]]; then
    configure_raid "${disques[@]}"
else
    echo "Configuration RAID annulée. Sélectionnez les disques pour l'installation."
    drive_count=1
    disque_selectionne=0
    for disk in "${disques[@]}"; do
        read -p "Utiliser $disk pour l'installation (o/n) ? " use_disk
        if [[ $use_disk == 'o' ]] || [[ $use_disk == 'y' ]]; then
            echo "DRIVE${drive_count} /dev/$disk" >> $AUTOSetup_FILE
            ((drive_count++))
            disque_selectionne=1
        fi
    done
    if [[ $disque_selectionne -eq 0 ]]; then
        echo -e "${RED}Aucun disque sélectionné pour l'installation. Annulation...${NC}"
        exit 1
    fi
fi

cat >> $AUTOSetup_FILE <<EOF
PART /boot ext3 512M
PART / ext4 all
#PART swap swap 16G
IMAGE /root/images/$IMAGE_CHOSEN
SSHKEYS_URL /root/.ssh/authorized_keys
EOF

echo "Le fichier de configuration /autosetup a été créé avec les paramètres suivants :"
cat $AUTOSetup_FILE
echo ""

read -p "Voulez-vous lancer installimage avec cette configuration (o/n) ? " execute_installimage
if [[ $execute_installimage == 'o' ]]; then
    echo "Lancement de installimage..."
    /root/.oldroot/nfs/install/installimage
else
    echo "Installation annulée par l'utilisateur."
    exit 0
fi

read -p "Voulez-vous redémarrer le serveur maintenant (o/n) ? " reboot_now
if [[ $reboot_now == 'o' ]]; then
    echo "Redémarrage du serveur..."
    sleep 2
    reboot
else
    echo "Redémarrage annulé par l'utilisateur."
fi

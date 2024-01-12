#!/bin/bash

echo "Configuration du Serveur Hetzner"
echo "--------------------------------"

# Demander à l'utilisateur de saisir le nom d'hôte
read -p "Entrez le nom d'hôte souhaité (ex: MonServeur): " HOSTNAME
echo ""

# Chemin vers le répertoire contenant les images
IMAGES_PATH="/root/images"

# Liste des images disponibles
echo "Images disponibles dans $IMAGES_PATH :"
AVAILABLE_IMAGES=($(ls $IMAGES_PATH))
for img in "${AVAILABLE_IMAGES[@]}"; do
    echo " - $img"
done

# Nom de l'image par défaut
DEFAULT_IMAGE="Debian-1202-bookworm-amd64-base.tar.gz"

# Demander le nom de l'image
read -p "Entrez le nom de l'image souhaitée (default: $DEFAULT_IMAGE): " IMAGE_CHOSEN
IMAGE_CHOSEN=${IMAGE_CHOSEN:-$DEFAULT_IMAGE}

# Lister les disques disponibles
echo "Liste des disques disponibles :"
disques=($(lsblk -d -n -o NAME | grep -E '^(s|nvme)'))
for disk in "${disques[@]}"; do
    disk_info=$(lsblk -d -n -o NAME,SIZE,MODEL /dev/$disk)
    echo "$disk_info"
done
echo ""

# Nombre de disques disponibles
nb_disques=${#disques[@]}

# Initialisation du fichier /autosetup
AUTOSetup_FILE="/autosetup"
cat > $AUTOSetup_FILE <<EOF
HOSTNAME $HOSTNAME
BOOTLOADER grub
EOF

# Compteur pour les identifiants de DRIVE
drive_count=1

# Instructions et configuration RAID
if [ $nb_disques -le 2 ]; then
    echo "Vous disposez de $nb_disques disque(s) pour la configuration RAID."
    read -p "Voulez-vous configurer un RAID avec ces disques (o/n) ? " choix_raid
    echo ""
    if [[ $choix_raid == 'o' ]]; then
        echo "SWRAID 1" >> $AUTOSetup_FILE
        echo "RAIDLEVEL 1" >> $AUTOSetup_FILE
        for disk in "${disques[@]}"; do
            echo "DRIVE${drive_count} /dev/$disk" >> $AUTOSetup_FILE
            ((drive_count++))
        done
    else
        echo "Configuration RAID annulée. Configuration standard des disques."
        for disk in "${disques[@]}"; do
            echo "DRIVE${drive_count} /dev/$disk" >> $AUTOSetup_FILE
            ((drive_count++))
        done
    fi
else
    echo "Vous pouvez créer plusieurs configurations RAID."
    echo "SWRAID 1" >> $AUTOSetup_FILE
    echo "RAIDLEVEL 1" >> $AUTOSetup_FILE
    read -p "Combien de configurations RAID voulez-vous créer ? " nb_raids
    echo ""
    for ((i=1; i<=nb_raids; i++)); do
        echo "Configuration pour le RAID $i :"
        read -p "Combien de disques dans ce RAID ? " nb_disques_dans_raid
        echo ""
        for ((j=1; j<=nb_disques_dans_raid; j++)); do
            read -p "Entrez le nom exact du disque $j pour le RAID $i (ex: sda, nvme0n1): " disk
            echo "DRIVE${drive_count} /dev/$disk" >> $AUTOSetup_FILE
            ((drive_count++))
        done
        echo ""
    done
fi

# Configuration de partitions et image
cat >> $AUTOSetup_FILE <<EOF
PART /boot ext3 512M
PART / ext4 all
#PART swap swap 16G
IMAGE /root/images/$IMAGE_CHOSEN
SSHKEYS_URL /root/.ssh/authorized_keys
EOF

# Affichage du fichier de configuration
echo "Le fichier de configuration /autosetup a été créé avec les paramètres suivants :"
cat $AUTOSetup_FILE
echo ""

# Confirmation avant de lancer installimage
read -p "Voulez-vous lancer installimage avec cette configuration (o/n) ? " execute_installimage
if [[ $execute_installimage == 'o' ]]; then
    echo "Lancement de installimage..."
    /root/.oldroot/nfs/install/installimage
else
    echo "Installation annulée par l'utilisateur."
    exit 0
fi

# Demander une confirmation avant de redémarrer
read -p "Voulez-vous redémarrer le serveur maintenant (o/n) ? " reboot_now
if [[ $reboot_now == 'o' ]]; then
    echo "Redémarrage du serveur..."
    sleep 2
    reboot
else
    echo "Redémarrage annulé par l'utilisateur."
fi

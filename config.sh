#!/bin/sh
# en root

# Mise à jour des paquets
apt update && apt upgrade -y
if [ $? -eq 0 ]; then
    echo "Mise à jour réussie."
else
    echo "Échec de la mise à jour."
    exit 1
fi

# Installation de cloud-init
apt install -y cloud-init
if [ $? -eq 0 ]; then
    echo "Installation de cloud-init réussie."
else
    echo "Échec de l'installation de cloud-init."
    exit 1
fi

# Modification de sshd_config
sed -i "s/PermitRootLogin prohibit-password/PermitRootLogin yes/g" "/etc/ssh/sshd_config"
if grep -q "PermitRootLogin yes" "/etc/ssh/sshd_config"; then
    echo "Modification de sshd_config réussie."
else
    echo "Échec de la modification de sshd_config."
    exit 1
fi

# Modification de /etc/network/interfaces
mv /etc/network/interfaces /etc/network/interfacesold
sed -n '1,4p' "/etc/network/interfacesold" > "/etc/network/interfaces"
if [ $? -eq 0 ]; then
    echo "Modification de /etc/network/interfaces réussie."
else
    echo "Échec de la modification de /etc/network/interfaces."
    exit 1
fi

# Modification de cloud.cfg
mv /etc/cloud/cloud.cfg /etc/cloud/cloudold.cfg
sed -i "s/disable_root: true/disable_root: false/g" "/etc/cloud/cloudold.cfg"
sed -n '1,/distro: debian/p; /# Other config here will be given to the distro class and/or path classes/,$p' "/etc/cloud/cloudold.cfg" > "/etc/cloud/cloud.cfg"
if [ $? -eq 0 ]; then
    echo "Modification de cloud.cfg réussie."
else
    echo "Échec de la modification de cloud.cfg."
    exit 1
fi

echo "Toutes les étapes ont été exécutées avec succès."

#!/bin/sh

# Mise à jour des paquets
apt update && apt upgrade -y

# Installation de cloud-init
apt install -y cloud-init

# Configuration de SSH pour autoriser la connexion en tant que root
SSH_CONFIG="/etc/ssh/sshd_config"
sed -i "s/#PermitRootLogin prohibit-password/PermitRootLogin yes/g" "$SSH_CONFIG"

# Sauvegarde et modification de la configuration réseau
NETWORK_CONFIG="/etc/network/interfaces"
cp "$NETWORK_CONFIG" "${NETWORK_CONFIG}old"
sed -n '1,4p' "${NETWORK_CONFIG}old" > "$NETWORK_CONFIG"

# Sauvegarde et modification de la configuration de cloud-init
CLOUD_CFG="/etc/cloud/cloud.cfg"
cp "$CLOUD_CFG" "${CLOUD_CFG}old"
sed -i "s/disable_root: true/disable_root: false/g" "${CLOUD_CFG}old"
sed -n '1,/distro: debian/p; /# Other config here will be given to the distro class and\/or path classes/,$p' "${CLOUD_CFG}old" > "$CLOUD_CFG"

# Redémarrage du service SSH pour appliquer les changements
systemctl restart sshd

# Vérification de la possibilité de se connecter en tant que root via SSH
if grep -q "PermitRootLogin yes" "$SSH_CONFIG"; then
    echo "Connexion SSH en tant que root autorisée."

    # Suppression de l'utilisateur 'user' si spécifié
    USERNAME_TO_DELETE="user"
    if id "$USERNAME_TO_DELETE" &>/dev/null; then
        deluser --remove-home "$USERNAME_TO_DELETE"
        echo "Utilisateur '$USERNAME_TO_DELETE' supprimé."
    else
        echo "Utilisateur '$USERNAME_TO_DELETE' non trouvé."
    fi
else
    echo "Erreur : La configuration SSH pour la connexion root n'a pas été mise à jour correctement."
fi

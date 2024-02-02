#!/bin/bash

# Chemin du fichier de configuration de minidlna
CONFIG_FILE="/etc/minidlna.conf"

# Répertoire de stockage des médias
MEDIA_DIR="/var/lib/minidlna"

install_minidlna() {
    # Vérifier si minidlna est installé
    if ! command -v minidlnad &> /dev/null
    then
        echo "Installation de minidlna..."
        sudo apt update
        sudo apt install -y minidlna
    else
        echo "minidlna est déjà installé."
    fi

    # Préparer le répertoire des médias
    if [ ! -d "${MEDIA_DIR}" ]; then
        echo "Création du répertoire des médias : ${MEDIA_DIR}"
        sudo mkdir -p "${MEDIA_DIR}"
        sudo chown -R minidlna:minidlna "${MEDIA_DIR}"
        sudo chmod -R 755 "${MEDIA_DIR}"
    else
        echo "Le répertoire des médias existe déjà."
    fi

    # Configuration de minidlna
    needs_restart=false

    # Modifier le fichier de configuration seulement si nécessaire
    if ! grep -q "^media_dir=V,${MEDIA_DIR}$" "${CONFIG_FILE}"; then
        echo "Configuration du répertoire des médias pour minidlna..."
        sudo sed -i "/^media_dir=/c\media_dir=V,${MEDIA_DIR}" "${CONFIG_FILE}"
        needs_restart=true
    fi

    if ! grep -q "^db_dir=/var/cache/minidlna" "${CONFIG_FILE}"; then
        sudo sed -i "/^#db_dir=/c\db_dir=/var/cache/minidlna" "${CONFIG_FILE}"
        needs_restart=true
    fi

    # Redémarrer minidlna si des modifications ont été apportées
    if $needs_restart; then
        echo "Redémarrage de minidlna pour appliquer les modifications..."
        sudo systemctl restart minidlna
        sudo systemctl enable minidlna
    else
        echo "Aucune modification de configuration nécessaire. minidlna n'a pas besoin d'être redémarré."
    fi

    echo "Installation et configuration de minidlna terminées."
}

uninstall_minidlna() {
    echo "Désinstallation de minidlna..."

    # Arrêter le service minidlna si en cours d'exécution
    sudo systemctl stop minidlna

    # Désactiver le service minidlna pour qu'il ne démarre pas au démarrage
    sudo systemctl disable minidlna

    # Supprimer le paquet minidlna
    sudo apt remove --purge -y minidlna

    # Supprimer les fichiers de configuration et les fichiers journaux
    sudo rm -rf /etc/minidlna.conf
    sudo rm -rf /var/cache/minidlna
    sudo rm -rf /var/log/minidlna*

    # Optionnel : Supprimer le répertoire des médias
    # Attention : décommentez la ligne suivante seulement si vous êtes sûr de vouloir supprimer le répertoire des médias et son contenu.
    # sudo rm -rf /var/lib/minidlna

    echo "minidlna a été complètement désinstallé."
}

case "$1" in
    install)
        install_minidlna
        ;;
    uninstall)
        uninstall_minidlna
        ;;
    *)
        echo "Usage: $0 {install|uninstall}"
        exit 1
        ;;
esac

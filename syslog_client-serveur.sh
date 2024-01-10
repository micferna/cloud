#!/bin/bash

# Adresse IP du serveur Syslog par défaut
DEFAULT_SERVER_IP="10.10.10.103"


# Fonction d'aide
show_help() {
    echo "Utilisation du script pour configurer un serveur/client Syslog"
    echo "Commandes :"
    echo "  bash $0 server                       - Installe et configure le serveur Syslog"
    echo "  bash $0 client                       - Installe le client Syslog avec l'adresse IP par défaut ($DEFAULT_SERVER_IP)"
    echo "  bash $0 client [adresse_ip_serveur]  - Installe le client Syslog avec une adresse IP spécifiée"
    echo ""
    echo "Exemples :"
    echo "  bash $0 server"
    echo "  bash $0 client"
    echo "  bash $0 client 10.10.10.103"
}

# Vérifier si l'utilisateur est root
if [[ $EUID -ne 0 ]]; then
   echo "Ce script doit être exécuté en tant que root" 
   exit 1
fi

# Fonction pour vérifier si rsyslog est installé
is_rsyslog_installed() {
    dpkg -s rsyslog &> /dev/null
    return $?
}

# Fonction pour vérifier si le serveur Syslog est déjà configuré
is_server_configured() {
    grep -q "module(load=\"imudp\")" /etc/rsyslog.conf && \
    grep -q "input(type=\"imudp\" port=\"514\")" /etc/rsyslog.conf
    return $?
}

# Fonction pour vérifier si le client Syslog est déjà configuré
is_client_configured() {
    [ -f /etc/rsyslog.d/50-default.conf ] && \
    grep -q "@.*:514" /etc/rsyslog.d/50-default.conf
    return $?
}

# Fonction pour configurer systemd-journald
configure_journald() {
    echo "ForwardToSyslog=yes" >> /etc/systemd/journald.conf
    echo "MaxRetentionSec=24hour" >> /etc/systemd/journald.conf  # Pour les VMs
    systemctl restart systemd-journald
}

configure_log_rotation() {
    echo "/var/log/*.log {
        daily
        missingok
        rotate 30
        compress
        delaycompress
        notifempty
        create 640 syslog adm
        sharedscripts
        postrotate
            systemctl restart rsyslog > /dev/null
        endscript
    }" > /etc/logrotate.d/rsyslog
}

# Fonction pour installer le serveur Syslog
install_server() {
    if is_rsyslog_installed && is_server_configured; then
        echo "Le serveur Syslog est déjà installé et configuré."
        return
    fi

    # Installer rsyslog si nécessaire
    if ! is_rsyslog_installed; then
        apt-get update
        apt-get install -y rsyslog
    fi

    # Configurer le serveur Syslog
    sed -i 's/#module(load="imudp")/module(load="imudp")/' /etc/rsyslog.conf
    sed -i 's/#input(type="imudp" port="514")/input(type="imudp" port="514")/' /etc/rsyslog.conf

    # Configurer systemd-journald pour rediriger vers rsyslog
    configure_journald
    configure_log_rotation

    # Redémarrer le service rsyslog
    systemctl restart rsyslog
    echo "Serveur Syslog installé et configuré."
}

# Fonction pour installer le client Syslog
install_client() {
    if is_client_configured; then
        echo "Le client Syslog est déjà configuré."
        return
    fi

    # Installer rsyslog si nécessaire
    if ! is_rsyslog_installed; then
        apt-get update
        apt-get install -y rsyslog
    fi

    # Utiliser l'adresse IP fournie ou l'adresse IP par défaut
    SERVER_IP=${1:-$DEFAULT_SERVER_IP}

    # Configurer le client Syslog pour rediriger les logs vers le serveur Syslog tout en les gardant localement
    echo "*.* @$SERVER_IP:514" | tee -a /etc/rsyslog.d/50-default.conf

    # Configurer systemd-journald pour rediriger vers rsyslog tout en conservant les logs localement pendant 24 heures
    configure_journald
    
    # Redémarrer le service rsyslog
    systemctl restart rsyslog
    echo "Client Syslog installé et configuré pour rediriger les logs vers le serveur Syslog tout en conservant les logs localement pendant 24 heures."
}

# Vérifiez si des arguments sont fournis
if [ $# -eq 0 ]; then
    show_help
    exit 1
fi

# Vérifier les arguments pour exécuter la bonne fonction
case "$1" in
    server)
        install_server
        ;;
    client)
        install_client "$2"
        ;;
    help | *)
        show_help
        exit 1
esac

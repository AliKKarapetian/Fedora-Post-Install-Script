#!/bin/bash

Key_Nvidia="/etc/pki/akmods/certs/public_key.der"

echo "========================================="
echo "       Configuration de la machine"
echo "========================================="

# Version de la machine
echo "######## VERSION DE L'OS"
grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"'
echo ""

# Type de session
echo "######## SESSION GRAPHIQUE"
env | grep -Po '(?<=XDG_SESSION_TYPE=).*' || echo "Non détectée (Script en root)"
echo ""

# TPM & Secure boot
echo "######## SECURE BOOT"
Secure_boot=$(mokutil --sb-state 2>/dev/null | grep -i "enabled")

if [[ -n "$Secure_boot" ]]; then
    echo "Secure Boot is ENABLED"
    SB_ACTIVE=true
else
    echo "Secure Boot is DISABLED"
    SB_ACTIVE=false
fi
echo ""

echo "######## TPM"
if [[ -f /sys/class/tpm/tpm0/tpm_version_major ]]; then
    TPM=$(cat /sys/class/tpm/tpm0/tpm_version_major)
    if [[ "$TPM" == "2" || "$TPM" == "1" ]]; then
        echo "TPM is active, version : TPM ${TPM}"
    else
        echo "TPM version inconnue : ${TPM}"
    fi
else
    echo "TPM is not active (Fichier introuvable)"
fi
echo ""
echo "========================================="


# --- 2. MISE À JOUR ---
echo -e "\nVoulez-vous lancer la mise à jour du système/Flatpak ?"
read -p "(y/N) " choix

if [[ "$choix" == "y" || "$choix" == "Y" ]]; then
    sudo dnf upgrade --refresh -y
    sudo flatpak update -y
else
    echo "Mise à jour annulée."
fi


# --- 3. CHOIX DES PILOTES GRAPHIQUES ---
echo -e "\n========================================="
echo "Pilotes graphiques :"
echo " 1 - NVIDIA"
echo " 2 - AMD"
echo " Autre touche - Passer (Skip)"
read -p "Choix : " Drive

if [[ "$Drive" == "1" ]]; then
    echo "Lancement de l'installation des pilotes NVIDIA..."
    if [[ "$SB_ACTIVE" == true ]]; then
        if [[ -f "$Key_Nvidia" ]]; then
            echo "Succès : La clé a bien été trouvée !"
        else
            echo "Création de la clé de validation..."
            sudo dnf install akmods mokutil -y
            sudo kmodgenca -a
            echo "ATTENTION : Le terminal va vous demander de créer un mot de passe."
            sudo mokutil --import "$Key_Nvidia"
        fi
    fi
    sudo dnf install -y akmod-nvidia xorg-x11-drv-nvidia-cuda xorg-x11-drv-nvidia-libs.i686 libva-vdpau-driver libva-utils
    echo "Installation NVIDIA terminée !"

elif [[ "$Drive" == "2" ]]; then
    echo "Lancement de l'installation des pilotes AMD..."
    sudo dnf install mesa-vulkan-drivers vulkan-loader radeontop -y
    sudo dnf swap mesa-va-drivers mesa-va-drivers-freeworld -y
    sudo dnf swap mesa-vdpau-drivers mesa-vdpau-drivers-freeworld -y
    echo "Terminé ! Les composants AMD sont à jour."

else
    echo "Installation des pilotes graphiques ignorée."
fi

# --- 5. INSTALLATION DES DÉPÔTS D'OFFICE (RPMFusion) ---
echo -e "\n========================================="
echo "Installation automatique des dépôts RPMFusion..."
echo "(Nécessaire pour les codecs, Steam, Discord, etc.)"
sudo dnf install https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm -y
sudo dnf install https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm -y
echo "Dépôts RPMFusion installés !"


# --- 6. INSTALLATION DES PAQUETS ET LOGS INTELLIGENTS ---
echo -e "\n========================================="
echo "Voulez-vous lancer l'installation des paquets depuis le fichier Paquet_RPM.txt ?"
read -p "(y/N) " Paquet_RPM

if [[ "$Paquet_RPM" == "y" || "$Paquet_RPM" == "Y" ]]; then

    if [[ ! -f "Paquet_RPM.txt" ]]; then
        echo "Erreur : Le fichier Paquet_RPM.txt est introuvable !"
    else
        LISTE_PAQUETS=""
        LISTE_FLATPAKS=""

        LOG_REUSSIS=""
        LOG_ECHECS=""
        FICHIER_LOG="Historique_Installations.log"
        DATE_ACTUELLE=$(date "+%Y-%m-%d %H:%M:%S")

        echo -e "\nAnalyse du fichier et vérification des paquets existants..."

        while read -r LINE; do
            LINE=$(echo "$LINE" | tr -d '\r')

            # 1. Ignorer lignes vides et commentaires
            if [[ -z "$LINE" ]] || [[ "$LINE" == \#* ]]; then
                continue
            fi

            # 2. Gestion des Dépôts (CORRIGÉ)
            if [[ "$LINE" == REPO:* ]]; then
                URL_DEPOT="${LINE#REPO:}"
                # On extrait juste le nom du fichier (ex: config.repo)
                NOM_FICHIER_REPO=$(basename "$URL_DEPOT")

                # On vérifie si ce fichier exact existe déjà dans le dossier des dépôts
                if [[ -f "/etc/yum.repos.d/$NOM_FICHIER_REPO" ]]; then
                    echo "  [SKIP] Dépôt déjà présent : $NOM_FICHIER_REPO"
                else
                    echo "  [AJOUT] Nouveau dépôt : $URL_DEPOT"
                    sudo dnf config-manager addrepo --from-repofile="$URL_DEPOT"
                fi

            # 3. Gestion des Flatpaks
            elif [[ "$LINE" == FLATPAK:* ]]; then
                NOM_FLATPAK="${LINE#FLATPAK:}"
                if flatpak info "$NOM_FLATPAK" &>/dev/null; then
                    echo "  [SKIP] Flatpak déjà installé : $NOM_FLATPAK"
                else
                    LISTE_FLATPAKS="$LISTE_FLATPAKS $NOM_FLATPAK"
                fi

            # 4. Gestion des paquets DNF normaux
            else
                if rpm -q "$LINE" &>/dev/null; then
                    echo "  [SKIP] Paquet déjà installé : $LINE"
                else
                    LISTE_PAQUETS="$LISTE_PAQUETS $LINE"
                fi
            fi
        done < Paquet_RPM.txt

        # --- INSTALLATION DNF ---
        if [[ -n "$LISTE_PAQUETS" ]]; then
            echo -e "\nInstallation des paquets DNF manquants : $LISTE_PAQUETS"
            sudo dnf install $LISTE_PAQUETS -y --skip-unavailable

            for PKG in $LISTE_PAQUETS; do
                if rpm -q "$PKG" &>/dev/null; then
                    LOG_REUSSIS="$LOG_REUSSIS $PKG"
                else
                    LOG_ECHECS="$LOG_ECHECS $PKG"
                fi
            done
        fi

        # --- INSTALLATION FLATPAK ---
        if [[ -n "$LISTE_FLATPAKS" ]]; then
            echo -e "\nInstallation des Flatpaks manquants : $LISTE_FLATPAKS"
            sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
            sudo flatpak install flathub $LISTE_FLATPAKS -y

            for FP in $LISTE_FLATPAKS; do
                if flatpak info "$FP" &>/dev/null; then
                    LOG_REUSSIS="$LOG_REUSSIS $FP"
                else
                    LOG_ECHECS="$LOG_ECHECS $FP"
                fi
            done
        fi

# --- 4. INSTALLATION DU CUSTOM SHELL (SYNTH SHELL) ---
echo -e "\n========================================="
echo "Voulez-vous installer le custom shell (Synth Shell) ?"
read -p "(y/N) " Custom_Shell

# Ajout du $ devant la variable pour bien lire la réponse de l'utilisateur
if [[ "$Custom_Shell" == "y" || "$Custom_Shell" == "Y" ]]; then
    
    # 1. Installation des polices obligatoires pour les symboles géométriques
    echo "Installation des polices Powerline requises"
    sudo dnf install powerline-fonts -y
    
    # 2. Téléchargement du code source
    echo "Téléchargement de Synth Shell"
    git clone --recursive https://github.com/andresgongora/synth-shell.git
    
    # 3. Lancement de l'installation
    echo "Lancement du script d'installation"
    cd synth-shell
    chmod +x setup.sh
    ./setup.sh
    
    # (Optionnel) Revenir au dossier parent une fois terminé
    cd .. 
    sudo rm -rf synth-shell
else
    echo "Installation du custom shell ignorée."
fi

        # --- ÉTAPE DE LOG ---
        echo -e "\n====================================="
        echo "Génération du journal d'installation..."

        echo "=====================================" >> "$FICHIER_LOG"
        echo "Date d'exécution : $DATE_ACTUELLE" >> "$FICHIER_LOG"

        if [[ -n "$LOG_REUSSIS" ]]; then
            echo "[SUCCÈS] Installés : $LOG_REUSSIS" >> "$FICHIER_LOG"
        fi

        if [[ -n "$LOG_ECHECS" ]]; then
            echo "[ERREUR] Introuvables ou échec : $LOG_ECHECS" >> "$FICHIER_LOG"
        fi

        if [[ -z "$LISTE_PAQUETS" ]] && [[ -z "$LISTE_FLATPAKS" ]]; then
            echo "[INFO] Aucun nouveau paquet n'avait besoin d'être installé." >> "$FICHIER_LOG"
        fi

        echo "Terminé ! Vérifiez le fichier $FICHIER_LOG pour voir ce qui a réussi ou échoué."
    fi
fi

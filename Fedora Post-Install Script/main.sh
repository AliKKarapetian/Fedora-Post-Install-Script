#!/bin/bash

## ── Couleurs (globales)
c=$'\e[36m'   # cyan   — clés
p=$'\e[35m'   # violet — hostname
b=$'\e[1m'    # gras
g=$'\e[32m'   # vert   — ok
y=$'\e[33m'   # jaune  — warn
r=$'\e[31m'   # rouge  — erreur
d=$'\e[90m'   # gris   — pipe │└
R=$'\e[0m'    # reset


key_nvidia="/etc/pki/akmods/certs/public_key.der"

## ── Fonctions 

afficher_infos_systeme() {

  _row() {
    echo -e "${d}${1}${R}${c}${2}${R} → ${3}${R}"
  }

  echo 
  local os
  os=$(grep '^PRETTY_NAME=' /etc/os-release | cut -d= -f2 | tr -d '"')
  _row ""   "OS"      "${os}"
  _row "│ " "Kernel"  "$(uname -r)"
  _row "│ " "Uptime"  "$(uptime -p | sed 's/up //')"
  _row "└ " "Session" "${XDG_SESSION_TYPE:-Non détectée}"
  echo

  local sb_val sb_col
  if mokutil --sb-state 2>/dev/null | grep -qi "enabled"; then
    sb_val="Activé";   sb_col="${g}"; SB_ACTIVE=true
  else
    sb_val="Désactivé"; sb_col="${y}"; SB_ACTIVE=false
  fi

  local tpm_val tpm_col
  if [[ -f '/sys/class/tpm/tpm0/tpm_version_major' ]]; then
    local v=$(</sys/class/tpm/tpm0/tpm_version_major)
    case "${v}" in
      1|2) tpm_val="Actif — version TPM ${v}"; tpm_col="${g}" ;;
      *)   tpm_val="Version inconnue : ${v}";   tpm_col="${y}" ;;
    esac
  else
    tpm_val="Inactif (fichier introuvable)"; tpm_col="${r}"
  fi

  _row ""   "Secure Boot" "${sb_col}${sb_val}"
  _row "└ " "TPM"         "${tpm_col}${tpm_val}"
  echo
}

installer_rpmfusion() {

  echo -e "\n${d}────────────────────────────────────────${R}"
  echo -e   "${c}Dépôts RPMFusion${R} → free & nonfree"
  echo -e   "${d}────────────────────────────────────────${R}\n"

  local ver
  ver=$(rpm -E %fedora)

  ## free
  if rpm -q rpmfusion-free-release &>/dev/null; then
    echo -e "${d}│${R} ${c}RPMFusion Free${R} → ${y}déjà installé, ignoré${R}"
  else
    echo -e "${d}│${R} ${c}RPMFusion Free${R} → installation en cours…"
    sudo dnf install -y \
      "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-${ver}.noarch.rpm" \
      &>/dev/null
  fi

  ## nonfree
  if rpm -q rpmfusion-nonfree-release &>/dev/null; then
    echo -e "${d}└${R} ${c}RPMFusion NonFree${R} → ${y}déjà installé, ignoré${R}"
  else
    echo -e "${d}└${R} ${c}RPMFusion NonFree${R} → installation en cours…"
    sudo dnf install -y \
      "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${ver}.noarch.rpm" \
      &>/dev/null
  fi

  echo -e "\n${d}  ${R}${g}Dépôts RPMFusion prêts.${R}\n"
}

lancer_mise_a_jour() {

  echo -e "\n${d}────────────────────────────────────────${R}"
  echo -e   "${c}Mise à jour${R} → système & Flatpak"
  echo -e   "${d}────────────────────────────────────────${R}\n"

  local choix
  read -rp "$(echo -e "${d}?${R} Lancer la mise à jour ? ${d}[y/N]${R} ")" choix

  if [[ "${choix}" == "y" || "${choix}" == "Y" ]]; then
    echo -e "${d}│${R} ${c}DNF${R} → mise à jour en cours…"
    sudo dnf upgrade --refresh -y &>/dev/null
    echo -e "${d}│${R} ${c}Flatpak${R} → mise à jour en cours…"
    sudo flatpak update -y &>/dev/null
    echo -e "${d}└${R} ${g}Mise à jour terminée.${R}\n"
  else
    echo -e "${d}└${R} ${y}Mise à jour annulée.${R}\n"
  fi
}

installer_pilotes_graphiques() {

  local choix

  echo -e "\n${d}────────────────────────────────────────${R}"
  echo -e   "${c}Pilotes graphiques${R} → choisir une option"
  echo -e   "${d}────────────────────────────────────────${R}"
  echo -e   "${d}│${R} ${c}1${R} → NVIDIA"
  echo -e   "${d}│${R} ${c}2${R} → AMD"
  echo -e   "${d}└${R} ${c}*${R} → Passer\n"

  read -rp "$(echo -e "${d}?${R} Choix : ")" choix

  case "${choix}" in

    1)
      echo -e "\n${d}│${R} ${c}NVIDIA${R} → installation en cours…"

      if [[ "${SB_ACTIVE}" == true ]]; then
        if sudo test -f "${key_nvidia}"; then
          echo -e "${d}│${R} ${c}Clé Secure Boot${R} → ${g}déjà présente${R}"
        else
          echo -e "${d}│${R} ${c}Clé Secure Boot${R} → création en cours…"
          sudo dnf install -y akmods mokutil &>/dev/null
          sudo kmodgenca -a
          echo -e "${d}│${R} ${y}⚠  Vous allez devoir créer un mot de passe MOK.${R}"
          sudo mokutil --import "${key_nvidia}"
        fi
      fi

      sudo dnf install -y \
        akmod-nvidia \
        xorg-x11-drv-nvidia-cuda \
        xorg-x11-drv-nvidia-libs.i686 \
        libva-vdpau-driver \
        libva-utils \
        &>/dev/null

      echo -e "${d}└${R} ${g}Pilotes NVIDIA installés.${R}\n"
      ;;

    2)
      echo -e "\n${d}│${R} ${c}AMD${R} → installation en cours…"

      sudo dnf install -y \
        mesa-vulkan-drivers \
        vulkan-loader \
        radeontop \
        &>/dev/null

      sudo dnf swap -y mesa-va-drivers    mesa-va-drivers-freeworld    &>/dev/null
      sudo dnf swap -y mesa-vdpau-drivers mesa-vdpau-drivers-freeworld &>/dev/null

      echo -e "${d}└${R} ${g}Pilotes AMD installés.${R}\n"
      ;;

    *)
      echo -e "${d}└${R} ${y}Installation des pilotes ignorée.${R}\n"
      ;;

  esac
}

installer_paquets() {

  echo -e "\n${d}────────────────────────────────────────${R}"
  echo -e   "${c}Installation des paquets${R} → Paquet_RPM.txt"
  echo -e   "${d}────────────────────────────────────────${R}\n"

  local choix
  read -rp "$(echo -e "${d}?${R} Lancer l'installation des paquets ? ${d}[y/N]${R} ")" choix
  [[ "${choix}" != "y" && "${choix}" != "Y" ]] && {
    echo -e "${d}└${R} ${y}Installation ignorée.${R}\n"; return;
  }

  if [[ ! -f "Paquet_RPM.txt" ]]; then
    echo -e "${d}└${R} ${r}Erreur : Paquet_RPM.txt introuvable !${R}\n"
    return 1
  fi

  local liste_dnf=""
  local liste_flatpak=""
  local log_ok=""
  local log_ko=""
  local fichier_log="Historique_Installations.log"
  local date_actuelle
  date_actuelle=$(date "+%Y-%m-%d %H:%M:%S")

  echo -e "${d}│${R} Analyse de Paquet_RPM.txt…\n"

  while read -r line; do

    line=$(echo "${line}" | tr -d '\r')

    ## ignorer lignes vides et commentaires
    [[ -z "${line}" || "${line}" == \#* ]] && continue

    case "${line}" in

      REPO:*)
        local url="${line#REPO:}"
        local nom=$(basename "${url}")
        if [[ -f "/etc/yum.repos.d/${nom}" ]]; then
          echo -e "${d}│  ${y}SKIP${R}    Dépôt    → ${nom}"
        else
          echo -e "${d}│  ${c}AJOUT${R}   Dépôt    → ${url}"
          sudo dnf config-manager addrepo --from-repofile="${url}" &>/dev/null
        fi
        ;;

      FLATPAK:*)
        local fp="${line#FLATPAK:}"
        if flatpak info "${fp}" &>/dev/null; then
          echo -e "${d}│  ${y}SKIP${R}    Flatpak  → ${fp}"
        else
          echo -e "${d}│  ${g}QUEUE${R}   Flatpak  → ${fp}"
          liste_flatpak+=" ${fp}"
        fi
        ;;

      *)
        if rpm -q "${line}" &>/dev/null; then
          echo -e "${d}│  ${y}SKIP${R}    DNF      → ${line}"
        else
          echo -e "${d}│  ${g}QUEUE${R}   DNF      → ${line}"
          liste_dnf+=" ${line}"
        fi
        ;;

    esac

  done < Paquet_RPM.txt

  ## ── Installation DNF ─────────────────────────────────────
  if [[ -n "${liste_dnf}" ]]; then
    echo -e "\n${d}│${R} ${c}DNF${R} → installation en cours…"
    sudo dnf install -y --skip-unavailable ${liste_dnf} &>/dev/null

    for pkg in ${liste_dnf}; do
      if rpm -q "${pkg}" &>/dev/null; then
        echo -e "${d}│  ${g}OK${R}      DNF      → ${pkg}"
        log_ok+=" ${pkg}"
      else
        echo -e "${d}│  ${r}ÉCHEC${R}   DNF      → ${pkg}"
        log_ko+=" ${pkg}"
      fi
    done
  fi

  ## ── Installation Flatpak ─────────────────────────────────
  if [[ -n "${liste_flatpak}" ]]; then
    echo -e "\n${d}│${R} ${c}Flatpak${R} → installation en cours…"
    sudo flatpak remote-add --if-not-exists flathub \
      https://flathub.org/repo/flathub.flatpakrepo &>/dev/null
    sudo flatpak install flathub -y ${liste_flatpak} &>/dev/null

    for fp in ${liste_flatpak}; do
      if flatpak info "${fp}" &>/dev/null; then
        echo -e "${d}│  ${g}OK${R}      Flatpak  → ${fp}"
        log_ok+=" ${fp}"
      else
        echo -e "${d}│  ${r}ÉCHEC${R}   Flatpak  → ${fp}"
        log_ko+=" ${fp}"
      fi
    done
  fi

  ## ── Log ──────────────────────────────────────────────────
  echo -e "\n${d}│${R} ${c}Journal${R} → génération en cours…"
  {
    echo "====================================="
    echo "Date d'exécution : ${date_actuelle}"
    if [[ -n "${log_ok}" ]]; then
      echo "[SUCCÈS] Installés :${log_ok}"
    fi
    if [[ -n "${log_ko}" ]]; then
      echo "[ERREUR] Échecs    :${log_ko}"
    fi
    if [[ -z "${liste_dnf}" && -z "${liste_flatpak}" ]]; then
      echo "[INFO]   Aucun nouveau paquet à installer."
    fi
    echo
  } >> "${fichier_log}"

  echo -e "${d}│${R} Log sauvegardé → ${fichier_log}"
  echo -e "${d}└${R} ${g}Installation terminée.${R}\n"
}

installer_synth_shell() {

  echo -e "\n${d}────────────────────────────────────────${R}"
  echo -e   "${c}Synth Shell${R} → custom shell & polices Powerline"
  echo -e   "${d}────────────────────────────────────────${R}\n"

  local choix
  read -rp "$(echo -e "${d}?${R} Installer Synth Shell ? ${d}[y/N]${R} ")" choix

  if [[ "${choix}" != "y" && "${choix}" != "Y" ]]; then
    echo -e "${d}└${R} ${y}Installation ignorée.${R}\n"
    return
  fi

  ## 1. polices Powerline
  echo -e "${d}│${R} ${c}Polices Powerline${R} → installation en cours…"
  sudo dnf install -y powerline-fonts &>/dev/null
  echo -e "${d}│${R} ${g}Polices installées.${R}"

  ## 2. téléchargement
  echo -e "${d}│${R} ${c}Synth Shell${R} → clonage du dépôt…"
  git clone --recursive https://github.com/andresgongora/synth-shell.git &>/dev/null

  if [[ ! -d "synth-shell" ]]; then
    echo -e "${d}└${R} ${r}Erreur : le clonage a échoué.${R}\n"
    return 1
  fi

  ## 3. installation
  echo -e "${d}│${R} ${c}setup.sh${R} → lancement…"
  (
    cd synth-shell || return 1
    chmod +x setup.sh
    ./setup.sh
  )

  ## 4. nettoyage
  echo -e "${d}│${R} ${c}Nettoyage${R} → suppression du dossier temporaire…"
  sudo rm -rf synth-shell

  echo -e "${d}└${R} ${g}Synth Shell installé.${R}\n"
}

main() {
    afficher_infos_systeme
    installer_rpmfusion
    lancer_mise_a_jour
    installer_pilotes_graphiques
    installer_paquets
    installer_synth_shell
}

main

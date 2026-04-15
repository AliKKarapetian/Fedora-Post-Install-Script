# 🖥️ Post-Install Fedora 43 — `main.sh`

Script de post-installation automatisé pour **Fedora 43**.  
Il configure le système, installe les pilotes, les dépôts et les paquets en une seule exécution.

> ℹ️ Développé et testé sur **KDE Plasma**, mais le script est compatible avec
> n'importe quel environnement graphique (GNOME, XFCE, Cinnamon, i3…).  
> Seul le fichier `Paquet_RPM.txt` est à adapter selon votre bureau — certains
> paquets comme `plasma-discover-packagekit` sont spécifiques à KDE.

---

## 📋 Prérequis

- Fedora 43 (tout environnement graphique)
- Connexion internet active
- Droits `sudo` disponibles
- Les deux fichiers dans le **même dossier** :
  - `main.sh`
  - `Paquet_RPM.txt`

---

## 🚀 Utilisation

```bash
# Rendre le script exécutable
chmod +x main.sh

# Lancer le script
./main.sh
```

> Le script est interactif : chaque étape demande une confirmation avant d'agir.

---

## 🔧 Étapes du script

### 1. Informations système

Affichée automatiquement au démarrage, sans interaction requise.

```
OS       → Fedora Linux 43 (KDE Plasma)
│ Kernel  → 6.x.x-xxx.fc43.x86_64
│ Uptime  → 2 minutes
└ Session → wayland

Secure Boot → Activé
└ TPM       → Actif — version TPM 2
```

Le statut du **Secure Boot** (`SB_ACTIVE`) est détecté ici et utilisé
automatiquement à l'étape NVIDIA pour gérer la clé MOK.

---

### 2. Dépôts RPMFusion

Installation automatique des dépôts **RPMFusion Free** et **NonFree**,
nécessaires pour les codecs, Steam, Discord, VirtualBox, etc.

- Si les dépôts sont déjà présents → ignorés (`SKIP`)
- Si absents → installés silencieusement

```
│ RPMFusion Free    → déjà installé, ignoré
└ RPMFusion NonFree → installation en cours…
```

---

### 3. Mise à jour du système

```
? Lancer la mise à jour ? [y/N]
```

| Réponse | Action |
|---------|--------|
| `y` | `dnf upgrade --refresh` + `flatpak update` |
| `N` | Étape ignorée |

---

### 4. Pilotes graphiques

```
│ 1 → NVIDIA
│ 2 → AMD
└ * → Passer
```

#### Option 1 — NVIDIA

> ✅ Ces pilotes sont les pilotes **propriétaires modernes** fournis par RPMFusion.
> Ils sont compatibles avec les cartes **RTX 3000 (Ampere) jusqu'aux dernières RTX 5000 (Blackwell)**,
> ainsi que les séries GTX récentes. Pour les très anciennes cartes (GTX 900 et antérieures),
> des paquets spécifiques peuvent être nécessaires.

Installe les paquets :
- `akmod-nvidia`
- `xorg-x11-drv-nvidia-cuda`
- `xorg-x11-drv-nvidia-libs.i686`
- `libva-vdpau-driver` / `libva-utils`

**Gestion automatique du Secure Boot :**  
Si le Secure Boot est actif, le script vérifie si la clé MOK
`/etc/pki/akmods/certs/public_key.der` est déjà présente.

| Situation | Action |
|-----------|--------|
| Clé présente | Ignorée, installation continue |
| Clé absente | `kmodgenca -a` + `mokutil --import` (mot de passe demandé) |

> ⚠️ Si une clé MOK est créée, un **redémarrage** sera nécessaire pour
> l'enrôler via l'interface UEFI avant que les modules NVIDIA se chargent.

#### Option 2 — AMD

> ⚠️ **Non testé** — Cette option n'a pas encore été validée sur une machine AMD.
> Les commandes sont basées sur la documentation RPMFusion et devraient fonctionner,
> mais utilisez-la avec précaution et vérifiez le résultat manuellement.

Installe et effectue les swaps freeworld :
- `mesa-vulkan-drivers`, `vulkan-loader`, `radeontop`
- `mesa-va-drivers` → `mesa-va-drivers-freeworld`
- `mesa-vdpau-drivers` → `mesa-vdpau-drivers-freeworld`

---

### 5. Installation des paquets (`Paquet_RPM.txt`)

```
? Lancer l'installation des paquets ? [y/N]
```

Le script lit `Paquet_RPM.txt` ligne par ligne et trie les paquets en trois catégories :

| Préfixe | Type | Exemple |
|---------|------|---------|
| `REPO:` | Dépôt distant `.repo` | `REPO:https://...config.repo` |
| `FLATPAK:` | Application Flatpak | `FLATPAK:com.teamspeak.TeamSpeak` |
| *(aucun)* | Paquet DNF standard | `vlc`, `steam`, `code` |

**Pendant l'analyse**, chaque paquet affiche son statut :

| Statut | Signification |
|--------|---------------|
| `SKIP` | Déjà installé, ignoré |
| `ATTENTE` | Absent, sera installé |

**Après l'installation**, le résultat est affiché et enregistré :

| Statut | Signification |
|--------|---------------|
| `OK` | Installation réussie |
| `ÉCHEC` | Paquet introuvable ou erreur |

Un fichier **`Historique_Installations.log`** est généré dans le même dossier :

```
=====================================
Date d'exécution : 2025-04-15 14:32:01
[SUCCÈS] Installés : vlc gimp htop steam ...
[ERREUR] Échecs    : discord
```

---

### 6. Synth Shell

```
? Installer Synth Shell ? [y/N]
```

Installe le prompt personnalisé [Synth Shell](https://github.com/andresgongora/synth-shell) :

1. Installation des polices **Powerline** (`powerline-fonts`)
2. Clonage du dépôt GitHub
3. Exécution du script `setup.sh` (interactif — choix du thème)
4. Suppression du dossier temporaire

> ℹ️ Le script `setup.sh` de Synth Shell est **interactif** :
> il posera des questions sur les composants à activer.

---

## 📄 Format de `Paquet_RPM.txt`

> ℹ️ Le fichier fourni est configuré pour **KDE Plasma**. Si vous utilisez un autre
> environnement graphique, adaptez la section *Boutique/Discover* et retirez les
> paquets spécifiques à KDE (`plasma-discover-packagekit`, `appstream-data`…)
> pour les remplacer par les équivalents de votre bureau.

```text
# Ceci est un commentaire — ignoré par le script

# Dépôt externe
REPO:https://packages.microsoft.com/yumrepos/vscode/config.repo

# Paquets DNF standard
vlc
gimp
htop

# Flatpak
FLATPAK:com.teamspeak.TeamSpeak
```

**Règles :**
- Les lignes commençant par `#` sont ignorées
- Les lignes vides sont ignorées
- Pas d'espace autour des `:` pour `REPO:` et `FLATPAK:`
- Un paquet par ligne

---

## 📁 Structure des fichiers

```
📂 dossier/
├── main.sh                      ← script principal
├── Paquet_RPM.txt               ← liste des paquets
└── Historique_Installations.log ← généré après installation
```

---

## ⚠️ Notes importantes

- Toutes les commandes `dnf` et `flatpak` s'exécutent en **mode silencieux**
  (`&>/dev/null`) — seuls les statuts finaux sont affichés.
- Le script nécessite `mokutil` et `openssl` pour la gestion Secure Boot NVIDIA
  (installés automatiquement si absents).
- Les variables de couleur (`$c`, `$g`, `$r`…) sont globales et disponibles
  dans toutes les fonctions.
- Développé et testé sur **Fedora 43 KDE Plasma** avec Bash 5.x — compatible avec tout autre environnement graphique Fedora moyennant adaptation du `Paquet_RPM.txt`.
- Les pilotes NVIDIA sont les pilotes **propriétaires modernes** (akmod) — compatibles RTX 3000 et supérieur. Non testé sur GTX ancienne génération.
- L'option AMD GPU **n'a pas été testée** — à utiliser avec précaution.

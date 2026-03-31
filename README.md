# 🚀 Fedora Post-Install Script

Ce script automatise la configuration de votre système Fedora après une installation fraîche. Il s'occupe des mises à jour, des pilotes graphiques et de l'installation de vos logiciels favoris.

---

## 📋 Prérequis

Avant de commencer, assurez-vous d'avoir :

- Téléchargé les deux fichiers dans le **même dossier** :
  - `mon_script.sh` — le script principal
  - `Paquet_RPM.txt` — la liste de vos logiciels
- Une **connexion internet** active

---

## 🛠️ Comment l'utiliser ?

**1.** Ouvrez un terminal dans le dossier où se trouvent les fichiers.

**2.** Rendez le script exécutable :

```bash
chmod +x mon_script.sh
```

**3.** Lancez le script avec les droits administrateur :

```bash
sudo ./mon_script.sh
```

---

## 🔍 Ce que fait le script

### 1. Diagnostic Système

Le script affiche d'abord un résumé de votre machine : version de Fedora, type de session (Wayland/X11), et état de sécurité (Secure Boot et TPM).

### 2. Mise à jour

Il vous propose de mettre à jour tous les paquets du système (DNF) ainsi que les applications Flatpak.

### 3. Pilotes Graphiques (NVIDIA ou AMD)

- **NVIDIA** : Installe les pilotes officiels, CUDA (pour le calcul) et les bibliothèques 32-bits (pour les jeux).
  > 💡 Si votre Secure Boot est activé, le script créera automatiquement une clé de signature pour que les pilotes fonctionnent.

- **AMD** : Installe les pilotes Vulkan et active l'accélération matérielle complète (codecs vidéo freeworld).

### 4. Installation de logiciels (via `Paquet_RPM.txt`)

Le script lit votre fichier texte et installe intelligemment :

| Type | Préfixe | Exemple |
|------|---------|---------|
| Dépôts | `REPO:` | VS Code, Brave |
| Applications isolées | `FLATPAK:` | TeamSpeak |
| Paquets classiques | *(aucun)* | VLC, Steam, Discord, Codecs… |

> ✅ **Intelligence du script** : Si un logiciel ou un dépôt est déjà présent, le script le détecte et passe au suivant pour ne pas perdre de temps.

---

## 📝 Suivi (Logs)

À la fin de l'exécution, un fichier **`Historique_Installations.log`** est créé. Vous pouvez l'ouvrir pour vérifier :

- Quels logiciels ont été installés avec succès
- S'il y a eu des erreurs (ex : paquet introuvable)

---

## ⚠️ Attention — Secure Boot & NVIDIA

Si vous installez les pilotes NVIDIA avec le Secure Boot activé, le script vous demandera de créer un **mot de passe court** (ex : `1234`).

Au prochain redémarrage, un écran bleu appelé **"MOK Management"** apparaîtra. Suivez ces étapes :

1. Choisissez **Enroll MOK**
2. Choisissez **Continue** puis **Yes**
3. Entrez le mot de passe créé pendant le script
4. **Redémarrez** — vos pilotes seront alors actifs

---

## 📄 Personnalisation

Vous pouvez modifier la liste des logiciels à installer en éditant simplement le fichier **`Paquet_RPM.txt`** avant de lancer le script.

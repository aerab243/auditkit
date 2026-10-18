# AuditKit

**Audit de santé et de sécurité Windows — en lecture seule, sans installation, avec rapport HTML autonome.**

[![Platform](https://img.shields.io/badge/Platform-Windows-0078D6?logo=windows&logoColor=white)](https://github.com/aerab243/auditkit)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B%20%2F%207%2B-012456?logo=powershell&logoColor=white)](https://github.com/aerab243/auditkit)
[![Read-only](https://img.shields.io/badge/Mode-100%25%20lecture%20seule-success)](https://github.com/aerab243/auditkit)

AuditKit inspecte un poste Windows et produit un **rapport HTML complet, consultable hors-ligne** (aucune dépendance externe, CSS embarqué). Il ne modifie **jamais** le système audité.

---

## 🎯 Objectif

AuditKit répond à un besoin simple : **obtenir en quelques secondes une photographie fiable de l'état d'un poste Windows**, sans installer d'agent, sans droits particuliers sur le réseau, et sans toucher au système.

L'outil est conçu pour :

| Public | Usage |
|---|---|
| **Techniciens / administrateurs système** | Vérifier rapidement la conformité d'un poste (pare-feu, antivirus, services) avant ou après une intervention |
| **Support / helpdesk** | Générer un rapport horodaté à joindre à un ticket pour diagnostiquer un incident |
| **Particuliers / curieux** | Contrôler l'état de santé de sa machine (RAM, disque, uptime) en un seul clic |

**Philosophie :**

- 🔒 **Lecture seule** — aucune écriture, aucune modification, aucune configuration changée.
- 📦 **Zéro installation** — un script PowerShell à exécuter, rien à déployer.
- 📊 **Rapport actionnable** — chaque vérification est notée `OK` / `WARN` / `FAIL` / `INFO` avec un message explicite.

---

## ✨ Fonctionnalités

| Domaine audité | Vérifications effectuées |
|---|---|
| 🖥️ **Système** | Version de Windows (build, architecture), mémoire RAM (totale / libre / utilisée), espace disque par lecteur, processeur, uptime |
| 🛡️ **Pare-feu** | État des 3 profils (Domaine / Privé / Public), action par défaut en entrée et en sortie |
| 🦠 **Antivirus** | Service Windows Defender, protection en temps réel, antimalware, ancienneté des définitions de virus, dernier scan |
| ⚙️ **Services** | Services automatiques arrêtés anormalement, état des services critiques réseau (DHCP, DNS, W32Time, Spooler…) |
| 📄 **Rapport** | Export HTML autonome avec résumé global, cartes de statistiques et tableaux de détails |

---

## 📋 Prérequis

| Prérequis | Détail |
|---|---|
| **Système** | Windows 10 / 11 ou Windows Server |
| **PowerShell** | 5.1 (intégré à Windows) ou PowerShell 7+ |
| **Droits** | Administrateur **recommandé** (certaines informations sont limitées sans : services, pare-feu, antivirus) |

---

## 🚀 Installation

Aucune installation n'est nécessaire. Clonez simplement le dépôt :

```powershell
git clone https://github.com/aerab243/auditkit.git
cd auditkit
```

> **Note :** si PowerShell affiche une erreur de stratégie d'exécution, utilisez l'option `-ExecutionPolicy Bypass` (voir ci-dessous). Cette option ne change **rien** à la configuration de votre machine : elle n'autorise le script que pour la session courante.

---

## ▶️ Utilisation

### Audit complet (recommandé)

Ouvrez PowerShell **en tant qu'administrateur**, placez-vous dans le dossier du projet et lancez :

```powershell
powershell -ExecutionPolicy Bypass -File .\AuditKit.ps1
```

### Options disponibles

| Paramètre | Description | Valeur par défaut |
|---|---|---|
| `-OutDir <chemin>` | Dossier où sera déposé le rapport HTML | `%USERPROFILE%\Documents\audit-reports` |
| `-Title <texte>` | Titre affiché dans le rapport | `AuditKit - Audit Windows` |
| `-Fast` | Mode rapide : n'exécute que les modules **Système** et **Pare-feu** | désactivé |

### Exemples

```powershell
# Audit complet, rapport dans le dossier par défaut
.\AuditKit.ps1

# Audit avec dossier de sortie et titre personnalisés
.\AuditKit.ps1 -OutDir .\reports -Title "Audit - Poste Comptabilite"

# Audit express (systeme + pare-feu uniquement)
.\AuditKit.ps1 -Fast
```

### Résultat

À la fin de l'exécution, AuditKit :

1. affiche un **résumé en console** (statut global + nombre de tests par statut) ;
2. génère un fichier `AuditKit_<NOM-DU-POSTE>_<horodatage>.html` dans le dossier de sortie ;
3. propose d'**ouvrir le rapport dans le navigateur**.

---

## 📊 Lire le rapport

### Les statuts

Chaque vérification reçoit l'un des quatre statuts suivants :

| Statut | Signification | Action attendue |
|---|---|---|
| ✅ `OK` | Conforme | Aucune |
| ⚠️ `WARN` | Avertissement — à surveiller | Corriger si possible, surveiller dans le temps |
| ❌ `FAIL` | Problème critique | **Correction recommandée** |
| ℹ️ `INFO` | Information (état constaté) | Aucune — élément de contexte |

Le **statut global** du rapport est calculé ainsi :

- `FAIL` si au moins un test est en échec ;
- sinon `WARN` si au moins un avertissement ;
- sinon `OK`.

### Seuils appliqués

Pour rester transparent, voici les règles de décision utilisées par les modules :

| Vérification | Seuil |
|---|---|
| Mémoire RAM | `FAIL` si < 4 Go · `WARN` si < 8 Go · sinon `OK` |
| Espace disque | `FAIL` si ≥ 90 % utilisé · `WARN` si ≥ 75 % utilisé · sinon `OK` |
| Pare-feu (par profil) | `FAIL` si désactivé |
| Protection temps réel | `FAIL` si désactivée |
| Définitions antivirus | `FAIL` si > 7 jours · `WARN` si > 3 jours · sinon `OK` |
| Dernier scan antivirus | `WARN` si > 7 jours |
| Services automatiques arrêtés | `WARN` |

---

## 🏗️ Architecture du projet

```
auditkit/
├── AuditKit.ps1              # Point d'entrée : orchestrateur
├── lib/
│   ├── Audit.Framework.psm1  # Moteur : structure du rapport + export HTML
│   ├── audit-report.css      # Feuille de style du rapport (embarquée à l'export)
│   └── modules/              # Un module par domaine d'audit
│       ├── Get-SystemInfo.psm1
│       ├── Get-FirewallInfo.psm1
│       ├── Get-AntivirusInfo.psm1
│       └── Get-ServiceErrors.psm1
├── .gitignore
└── README.md
```

### Chaîne d'exécution

```
AuditKit.ps1 (orchestrateur)
   │
   ├─ 1. Vérifie la version de PowerShell et les droits administrateur
   ├─ 2. Charge lib/Audit.Framework.psm1 (le moteur)
   ├─ 3. Charge les modules sélectionnés (tous, ou Système + Pare-feu en mode -Fast)
   ├─ 4. Crée le rapport via New-AuditReport
   ├─ 5. Exécute chaque module : chacun remplit ses sections et ses tests
   ├─ 6. Calcule le résumé via Get-AuditSummary
   └─ 7. Exporte le HTML via Export-AuditReportHtml
```

Cette séparation rend le projet **facilement extensible** : ajouter un audit = ajouter un module, sans toucher au moteur.

---

## 🔧 Contribuer

Les contributions sont les bienvenues ! Que ce soit pour corriger un bug, ajouter un module d'audit ou améliorer la documentation.

### Workflow Git

1. **Forkez** le dépôt, puis clonez votre fork :
   ```bash
   git clone https://github.com/<votre-utilisateur>/auditkit.git
   cd auditkit
   ```
2. **Créez une branche** dédiée :
   ```bash
   git checkout -b feat/module-mises-a-jour
   # ou : fix/affichage-resume
   ```
3. **Commitez** vos modifications avec un message clair :
   ```bash
   git commit -m "feat(updates): ajoute le module d'audit des mises a jour Windows"
   ```
4. **Poussez** et ouvrez une **Pull Request** vers `main` :
   ```bash
   git push origin feat/module-mises-a-jour
   ```

> Préfixes de commit conseillés : `feat:` (fonctionnalité), `fix:` (correction), `docs:` (documentation), `refactor:`, `chore:`.

### Ajouter un module d'audit

C'est le cas de contribution le plus courant. Trois étapes :

**1. Créez le fichier** `lib/modules/Get-<Domaine>Info.psm1` :

```powershell
<#
.SYNOPSIS
    Module d'audit : <Domaine>.
.DESCRIPTION
    Verifie : <ce que le module controle>.
#>

Set-StrictMode -Version Latest

function Get-Audit<Domaine> {
    param(
        [Parameter(Mandatory) [object]$Report
    )

    # 1) Creer une section dans le rapport
    $section = Add-AuditSection $Report -Name "<Domaine>" `
        -Description "<description affichee dans le rapport>"

    # 2) Ajouter des tests avec un statut et un message
    $test = Add-AuditTest $section -Name "<Nom du test>" -Status "INFO" `
        -Message "<message explicite>"

    # 3) (Optionnel) Ajouter un tableau de details
    Add-AuditDetail $test -Rows @(
        [pscustomobject]@{ Propriete = 'Valeur 1' },
        [pscustomobject]@{ Propriete = 'Valeur 2' }
    )

    return
}

Export-ModuleMember -Function Get-Audit<Domaine>
```

**2. Enregistrez-le** dans `AuditKit.ps1`, dans la table de correspondance `$auditFunctions` :

```powershell
$auditFunctions = @{
    'Get-SystemInfo.psm1'     = { Audit-SystemInfo $report | Out-Null }
    # ...
    'Get-<Domaine>Info.psm1'  = { Get-Audit<Domaine> $report | Out-Null }
}
```

**3. Testez** :

```powershell
.\AuditKit.ps1 -OutDir .\reports -Title "Test nouveau module"
```

### API du framework (`Audit.Framework.psm1`)

Toutes les fonctions dont un module a besoin :

| Fonction | Rôle |
|---|---|
| `New-AuditReport -HostName <nom> [-Title <titre>]` | Crée un rapport vide |
| `Add-AuditSection -Report $report -Name <nom> [-Description <texte>]` | Ajoute une section, retourne la section |
| `Add-AuditTest -Section $section -Name <nom> -Status <OK\|WARN\|FAIL\|INFO> [-Message <texte>]` | Ajoute un test, retourne le test |
| `Add-AuditDetail -Test $test -Rows @(...)` | Attache un tableau de détails à un test |
| `Get-AuditSummary -Report $report` | Calcule les compteurs et le statut global |
| `Export-AuditReportHtml -Report $report -Path <fichier.html>` | Génère le rapport HTML |
| `Invoke-AuditCommand -Command { ... }` | Exécute une commande en capturant les erreurs (ne casse jamais l'audit) |

### Conventions de code

- **Langue** : code, commentaires et messages en français (langue du projet).
- **Encodage** : UTF-8 pour tous les fichiers.
- **Sécurité** : un module ne doit **jamais** modifier le système (lecture seule obligatoire).
- **Robustesse** : utiliser `Invoke-AuditCommand` pour les commandes susceptibles d'échurer, afin qu'une erreur n'interrompe pas l'audit complet.
- **Statuts** : n'utiliser que `OK`, `WARN`, `FAIL`, `INFO`, et documenter tout nouveau seuil dans le tableau des seuils du README.
- **Verbes PowerShell** : utiliser un verbe approuvé (`Get-`, `Test-`, `Invoke-`…). Les fonctions d'audit suivent la convention `Get-Audit<Domaine>` (ex. `Get-AuditSystem`) afin d'éviter les avertissements à l'import des modules.

### Signaler un bug

Ouvrez une *issue* sur GitHub en précisant : la version de Windows, la version de PowerShell, la commande lancée et le message d'erreur observé.

---

## 🔒 Sécurité et confidentialité

- **Lecture seule** : AuditKit exécute exclusivement des commandes de consultation (`Get-CimInstance`, `Get-Service`, `Get-NetFirewallProfile`, `Get-MpComputerSecurity`…). Il n'installe rien, ne modifie aucun paramètre et ne contacte aucun serveur.
- **Données sensibles** : les rapports contiennent des informations sur la machine (nom d'hôte, version de l'OS, logiciels installés, configuration réseau…). Ne les partagez pas publiquement et stockez-les comme toute donnée sensible.
- **Dépôt** : les rapports générés et fichiers de test sont exclus du dépôt via `.gitignore`.

---

## 🐛 Dépannage

| Problème | Solution |
|---|---|
| `L'exécution de scripts est désactivée sur ce système` | Relancez avec `powershell -ExecutionPolicy Bypass -File .\AuditKit.ps1` (valable uniquement pour cette exécution) |
| Informations manquantes (services, pare-feu, antivirus) | Le script n'a pas été lancé en administrateur — relancez PowerShell en tant qu'administrateur |
| L'audit antivirus reste silencieux | Windows Defender est absent (certaines éditions de Windows) — les tests concernés sont alors simplement ignorés |
| Rapport HTML vide ou erreur à l'export | Vérifiez les droits d'écriture sur le dossier `-OutDir` |

---

## 🗺️ Idées d'évolution

- Exports complémentaires (JSON, CSV) pour l'automatisation
- Modules additionnels : mises à jour Windows, comptes locaux, partages réseau, certificats
- Seuils de tolérance configurables (fichier de configuration)
- Comparaison de deux audits (avant / après intervention)

---

## 📄 Licence

Aucune licence n'est définie pour l'instant. Le mainteneur peut ajouter un fichier `LICENSE` (par exemple MIT) pour autoriser explicitement la réutilisation et la contribution.

---

**Dépôt :** https://github.com/aerab243/auditkit

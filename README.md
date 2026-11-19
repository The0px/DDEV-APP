# DDEV-APP

Application macOS native (Swift/SwiftUI) pour gérer ses projets [DDEV](https://ddev.com) sans passer par le terminal.

## Objectif

Offrir une interface macOS native au-dessus de la CLI `ddev` : voir ses projets et leur état, les démarrer ou les arrêter, ouvrir leur URL et gérer leurs add-ons.

## Prérequis

- macOS 14 (Sonoma) ou plus récent
- [DDEV](https://ddev.readthedocs.io/en/stable/users/install/ddev-installation/) installé (`ddev` dans `/opt/homebrew/bin`, `/usr/local/bin` ou le `PATH`)
- Un fournisseur Docker : [Docker Desktop](https://www.docker.com/products/docker-desktop/), [OrbStack](https://orbstack.dev) ou [Colima](https://github.com/abiosoft/colima)
- Xcode 16 ou une toolchain Swift 6 pour compiler

## Structure

| Dossier | Rôle |
| --- | --- |
| `Sources/DDEVKit` | Bibliothèque sans interface : modèles et client de la CLI `ddev` |
| `Tests/DDEVKitTests` | Tests XCTest de `DDEVKit` |

## Compiler et tester

```bash
swift build
swift test
```

## Feuille de route

### 1. Architecture

- [x] Cœur de `DDEVClient` : `listProjects()` async, exécution de `ddev` derrière un protocole simulable, erreurs typées, tests unitaires associés
- [ ] Application SwiftUI (projet Xcode) qui s'appuie sur `DDEVKit`
- [ ] État partagé `@Observable` alimenté par `DDEVClient`
- [ ] Actions sur un projet : `start`, `stop`, `restart`, ouverture de l'URL

### 2. Surveillance Docker et DDEV

- [ ] Détection du fournisseur Docker (Docker Desktop, OrbStack, Colima) et de son état
- [ ] Rafraîchissement périodique de l'état des projets
- [ ] Notifications lors d'un changement d'état

### 3. Gestion des add-ons

- [ ] Liste des add-ons installés par projet
- [ ] Recherche et installation d'add-ons (`ddev add-on get`)
- [ ] Suppression d'add-ons

### 4. Tests

- [ ] Tests de l'état `@Observable`
- [ ] Tests d'intégration contre une vraie installation DDEV
- [ ] Tests d'interface de l'application

## Licence

[MIT](LICENSE)

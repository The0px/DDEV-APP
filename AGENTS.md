# AGENTS.md

Règles pour tout agent (IA ou bot) qui travaille sur DDEV-APP. Lis ce fichier en entier avant ta première modification. En cas de doute entre aller vite et respecter une règle d'ici, respecte la règle.

## Le projet en bref

Application macOS native (Swift 6, SwiftUI, macOS 14+) qui pilote la CLI `ddev` : liste des projets, démarrage, arrêt, redémarrage, mise à jour automatique via `docker events`.

| Dossier | Rôle |
| --- | --- |
| `Sources/DDEVKit` | Bibliothèque sans interface : modèles, `DDEVClient`, exécution de processus, `DockerEventsClient`, `ProjectStore` (`@Observable`) |
| `Tests/DDEVKitTests` | Tests XCTest de `DDEVKit`, données fictives dans `Fixtures/` |
| `DDEVApp` | Application SwiftUI (projet Xcode qui dépend du package local `..`) |
| `docs/screenshots` | Captures du README |

Toute la logique testable vit dans `DDEVKit`. L'app ne fait que de l'affichage et délègue au `ProjectStore`.

## Commandes

```bash
swift build
swift test
xcodebuild -project DDEVApp/DDEVApp.xcodeproj -scheme DDEVApp -derivedDataPath build build
open build/Build/Products/Debug/DDEVApp.app --args --demo
```

- `swift test` n'a besoin ni de DDEV ni de Docker : les appels passent par `MockProcessRunner` ou par de faux scripts shell.
- `--demo` lance l'app avec des projets fictifs (`DemoProcessRunner`) : c'est le mode à utiliser pour vérifier l'interface.
- Sans `--demo`, l'app agit sur les **vrais** projets DDEV de la machine. Voir « Interdictions ».

## Définition de « terminé »

Une tâche n'est terminée que si **toutes** ces conditions sont vraies :

1. `swift build` et `swift test` passent, sans nouvel avertissement de concurrence.
2. `xcodebuild … build` passe si un fichier de `DDEVApp/` a changé.
3. Tout comportement nouveau ou corrigé dans `DDEVKit` a un test qui échouait avant le changement.
4. Une modification d'interface a été vérifiée dans l'app lancée en `--demo` (capture d'écran à l'appui), en mode clair et en mode sombre.
5. Le README est à jour si une fonctionnalité, une commande ou un prérequis a changé (cocher la feuille de route si besoin).

« Ça compile » ne suffit pas. Ne déclare jamais un test vert sans l'avoir lancé, et rapporte un échec tel quel, sortie comprise.

## Conventions de code

- **Swift 6 strict** : concurrence stricte, `Sendable` correct, `@MainActor` sur ce qui touche l'interface. Pas de `@unchecked Sendable` ni de `nonisolated(unsafe)` pour faire taire le compilateur.
- **Erreurs typées** : `throws(DDEVError)` côté `DDEVClient`. Chaque nouveau cas de `DDEVError` a un message en français qui dit quoi faire.
- **Aucune dépendance externe.** Foundation, SwiftUI, AppKit, XCTest. Rien d'autre sans accord explicite.
- **Fichiers petits et ciblés** : un type par fichier, rangé dans le dossier de son domaine (`Models`, `Process`, `Docker`, `Store`, `Views`).
- **Pas de logique dupliquée** : une action partagée entre plusieurs vues va dans un seul composant (exemple : `ProjectActionButtons`, utilisé par la fiche et le menu contextuel).
- **Tout ce qui lance un processus passe par une abstraction injectable** (`ProcessRunning`, `ExecutableLocator`, `ProjectStore.EventSource`), pour rester testable sans DDEV.
- **Commentaires** en français, courts, qui expliquent un *pourquoi* que le code ne dit pas. Pas de narration ni d'historique.
- **Interface** : textes en français, contrastes WCAG respectés (la couleur d'état reste sur la pastille, pas sur le texte), libellés d'accessibilité sur les éléments composés.
- Avant d'utiliser une API Apple dont tu n'es pas sûr, vérifie la documentation à jour plutôt que ta mémoire.

## Interdictions

Ces règles ne se négocient pas, même pour « débloquer » une tâche.

**Fichiers et Git**

- Pas de `rm -rf`, pas de suppression en masse, pas de `git clean -fdx`. Pour retirer un fichier suivi, `git rm <fichier>` sur des chemins précis et justifiés.
- Pas de `git push --force`, `git reset --hard`, `git rebase` sur une branche publiée, ni de réécriture d'historique.
- Ne jamais committer `build/`, `.build/`, `DerivedData/`, `xcuserdata/`, de secret ou de fichier personnel. Vérifie `git status` avant chaque commit.
- Ne pas modifier `DDEVApp/DDEVApp.xcodeproj/project.pbxproj` à la main sauf nécessité : le projet utilise des dossiers synchronisés, un nouveau fichier Swift dans `DDEVApp/DDEVApp/` est pris en compte automatiquement.

**Machine et système**

- Ne jamais cliquer sur une demande d'autorisation macOS (accès à Documents, Bureau, Téléchargements, Accessibilité, Enregistrement de l'écran). Elles appartiennent au propriétaire de la machine : signale-la et attends.
- Ne jamais démarrer, arrêter, redémarrer ou supprimer un vrai projet DDEV, ni lancer `ddev delete`, `ddev poweroff`, `docker rm`, `docker system prune` ou arrêter le fournisseur Docker, sans accord explicite pour ce projet précis.
- Ne pas modifier `~/.ddev`, la configuration de Docker ou d'OrbStack, ni les fichiers `.ddev/` des projets de l'utilisateur.

**Périmètre**

- Pas de réécriture d'un fichier entier, de changement d'architecture ou de renommage de types publics de `DDEVKit` sans accord préalable. Corrige au plus près du problème.
- Pas de nouvelle fonctionnalité non demandée « tant que tu y es ».
- Pas de désactivation, suppression ou affaiblissement d'un test pour le faire passer. Un test rouge signale un problème dans le code, ou un test faux qu'il faut corriger en expliquant pourquoi.

## Garde-fous contre les boucles

Un agent qui « continue jusqu'à avoir du bon code » sans limite brûle du temps et réécrit ce qui marchait. Donc :

- **Trois tentatives au maximum** pour corriger un même échec (test, compilation, comportement). Après la troisième, arrête-toi et rapporte : ce qui échoue, ce que tu as essayé, ton hypothèse.
- **Un changement à la fois** : un commit répond à un seul problème et reste lisible en une relecture (repère : moins de 300 lignes modifiées hors tests et fixtures).
- **Si un diff grossit au-delà de ce qui était prévu**, arrête-toi et demande avant de continuer.
- **Ne pas tourner en rond sur une cause externe** : Docker arrêté, DDEV absent, autorisation macOS en attente, réseau coupé. Ce ne sont pas des bugs du code, signale-les.
- **Deuxième avis obligatoire** pour un changement risqué (exécution de processus, `ProjectStore`, timeouts, flux `docker events`, suppression de code) : un autre agent ou un humain relit le diff avant la fusion.

## Autonomie, commits et rapports

- Travaille sur une branche (`bot/<sujet-court>`) et ouvre une pull request avec `gh pr create`. Pousser directement sur `main` seulement si le mainteneur le demande.
- Messages de commit en français, au présent, qui commencent par un verbe : « Ajoute… », « Corrige… », « Rafraîchit… ». Une ligne de titre courte, puis le pourquoi si besoin. Pas de ligne d'attribution.
- La description de la PR liste : ce qui change, pourquoi, comment c'est vérifié (commandes lancées, captures), et ce qui n'a **pas** été vérifié.
- **Rapports sur Discord** : un message par tâche terminée ou bloquée, pas un par étape. Format : statut (terminé, bloqué, régression), lien vers la PR ou le commit, deux ou trois lignes maximum. Pas de mention `@` sauf blocage qui demande une décision humaine.
- **Régression détectée** (par exemple après une nouvelle version de DDEV) : ouvre une issue avec la commande, la sortie obtenue et la sortie attendue, puis propose un correctif dans une PR séparée. Un seul message pour la régression, mis à jour plutôt que répété.

## Pièges connus

- **`ddev list` peut bloquer indéfiniment** : Docker arrêté, ou demande d'autorisation macOS en attente pour un projet rangé dans Documents. D'où le délai de 20 s (600 s pour les actions) et l'arrêt forcé (SIGTERM puis SIGKILL après 2 s, car `ddev` ignore parfois SIGTERM). Ne retire pas ces délais.
- **Le `PATH` d'une app graphique** ne contient pas celui du shell : `ProcessEnvironment` ajoute `/opt/homebrew/bin`, `/usr/local/bin`, `~/.orbstack/bin` et le dossier de l'exécutable. Un « ddev introuvable » vient souvent de là.
- **Sortie JSON de `ddev`** : plusieurs lignes `{"level","msg"}` avant celle qui contient `raw`. `raw: null` signifie aucun projet. Les champs inconnus doivent rester tolérés.
- **`docker events`** : les filtres `event=` répétés se combinent en OU, des filtres différents en ET. Ne pas écouter les `exec_*` (les healthchecks en produisent en continu). `health_status` ne part qu'au changement de santé ; sans lui, un projet reste affiché en « Démarrage ».
- **Pas d'App Sandbox**, volontairement : un processus enfant hérite du sandbox et `ddev` ne pourrait plus écrire dans `~/.ddev` ni joindre le socket Docker. Ne l'active pas.
- **Signature locale** : après une recompilation, macOS peut redemander l'accès aux dossiers protégés. C'est attendu, voir la règle sur les autorisations.
- **Captures d'écran** : `screencapture` échoue sans l'autorisation d'enregistrement de l'écran. Utilise l'outil d'automatisation graphique (capture de la fenêtre de l'app) et écris d'abord dans un dossier temporaire avant de copier dans `docs/screenshots`.
- **Automatisation de l'interface** : en cliquant par libellé, « Redémarrer » existe aussi dans le menu Pomme. Cible le bouton par son identifiant d'élément dans la fenêtre de DDEV-APP, jamais par texte seul.

## Quand t'arrêter et demander

- Une règle de ce fichier t'empêche d'avancer.
- La tâche demande d'agir sur un vrai projet DDEV, sur Docker ou sur une autorisation système.
- Trois tentatives ont échoué.
- Le changement dépasse le périmètre demandé ou touche l'architecture.
- Tu n'es pas sûr de l'intention. Une question coûte moins cher qu'une nuit de commits à défaire.

---
name: luanti-test-debug
description: Teste et débogue le mod paleocave dans le vrai moteur Luanti 5.18 en headless - lint (luacheck ou fallback LuaJIT), test de chargement, test de génération d'une caverne (fuites d'eau, sol éclairé, créatures placées), monde de dev pour le test en jeu, lecture du log. À utiliser après toute modification ou quand quelque chose plante.
---

# Tester paleocave

On teste dans le **vrai moteur** (Luanti 5.18 en headless), comme pour la cavepatate : jamais de faux `core` réécrit à la main.
Ne rien installer ni télécharger (Luanti, luacheck, PaleoTest...) sans accord explicite.

Scripts dans `.claude/skills/luanti-test-debug/scripts/`, utilisables depuis n'importe quel dossier :

| But | Commande |
|---|---|
| Lint : luacheck, sinon LuaJIT (syntaxe + globales) | `lint.sh [fichiers.lua...]` |
| Chargement headless, monde temporaire hors projet | `load_test.sh [secondes]` |
| Génération d'une caverne, avec bilan | `[SEED=42] [LEVEL=1] [HALF=80] smoke_test.sh` |
| Monde de dev pour le test en jeu | `dev_world.sh [--new] [--launch]` |

`lib.sh` regroupe le code commun (binaire Luanti, mods disponibles, monde temporaire, analyse du log).

## Environnement
- Luanti 5.18.0 : `~/Downloads/luanti.app/Contents/MacOS/luanti`, trouvé automatiquement (`LUANTI_BIN` pour en changer).
- Données utilisateur : `~/Library/Application Support/minetest/` (jeu `minetest_game` = gameid `minetest`, `mods/`, `worlds/`).
- Dépendances à fournir : `paleotest`, `mob_core`, `mobkit`, listées dans `.claude/test_mods.txt`. Soit installées dans `<données>/mods/`, soit passées par chemin, sans installation : `EXTRA_WORLDMODS=chemin1:chemin2 <script>`. Sinon les scripts s'arrêtent (code 2) en nommant les mods manquants.
- LuaJIT 2.0.5 sur la machine (le moteur embarque LuaJIT 2.1), luacheck absent, Python 3.14 sans PIL.

## 1. Lint (toujours, rapide)
`lint.sh` : luacheck avec `scripts/luacheckrc` s'il est installé. Sinon LuaJIT vérifie la syntaxe et repère dans le bytecode les globales **écrites** (oubli de `local`) et **lues** inconnues (faute de frappe, dépendance non déclarée). Une nouvelle globale légitime s'ajoute à `READ_OK` dans `lint.sh` **et** à `luacheckrc`.

## 2. Chargement (`load_test.sh`)
Serveur headless dans `$TMPDIR/paleocave_loadtest` (mapgen v7 pour que `mapgen.lua` s'enregistre en entier, écoute sur 127.0.0.1 seulement), quelques secondes, arrêt, puis analyse du log. Signale un crash au chargement, tout `ERROR[...]`, et les `WARNING[...]` qui citent le mod, une API dépréciée ou un nom inconnu. Codes : 0 OK, 1 problème, 2 impossible de lancer. Sans joueur, aucun chunk n'est généré : voir le test suivant.

## 3. Génération (`smoke_test.sh`)
Monde `$TMPDIR/paleocave_smoketest`, mapgen v7, graine fixe (`SEED`), carte de ±10000. Un mod d'aide écrit dans ce monde, jamais dans le projet, appelle `paleocave.caves.get_levels()`, génère le centre de la caverne `LEVEL` (±`HALF` nœuds, toute la hauteur du niveau ; le cratère du volcan est dedans) avec `core.emerge_area`, puis journalise :
- la position et le niveau de la mer des 5 cavernes, la position du volcan, la durée de génération ;
- les nœuds par nom, les créatures placées (comptées dans `core.add_entity`) ;
- dans les colonnes de la caverne et de ses parois seulement (`caves.column_model`) : les fuites d'eau et de lave (liquide à côté ou au-dessus d'un vide), les liquides qui coulent déjà, les blocs de donjon à l'air libre, la part du sol éclairé (lumière ≥ 8 au-dessus de l'herbe).

Échec si erreur, fuite d'eau ou de lave, liquide qui coule, donjon visible, ou génération inachevée avant `SMOKE_TIMEOUT` (300 s). `HALF=260` vérifie toute la caverne avec ses bords (là où débordent les mapchunks voisins), en une minute environ ; mettre alors `SMOKE_TIMEOUT=900`. Pour voir les blocs violets du volcan, ajouter un clone d'Everness à `EXTRA_WORLDMODS` (sinon : repli gravier, obsidienne, pierre). Avec des mods vides à la place de PaleoTest, seul le terrain est validé : pins à la place des métaséquoias, ni cycas, ni prêles, ni créatures.

## 4. En jeu (`dev_world.sh`, puis l'utilisateur joue)
Lie le mod dans `<données>/mods/paleocave` (le code est lu en direct) et crée le monde créatif `paleocave_dev` avec les mods de `test_mods.txt`. `--new` le recrée : **obligatoire après une modification du générateur**, les chunks déjà générés ne changent plus. `--launch` ouvre une fenêtre Luanti : seulement si l'utilisateur le demande. Aucun autre monde n'est touché.

Checklist à proposer : `/grantme all`, `/paleocave` (coordonnées de la caverne la plus proche), `/teleport` :
- cavernes, mers, ambre lumineux, vignes, arbres, peintures rupestres ;
- les dinosaures sont déjà là à l'arrivée (placés à la génération), les marins dans l'eau seulement ;
- piliers en sablier du sol au plafond, boules d'ambre rares au plafond avec un ambersol, sol bien éclairé ;
- ruines : aucun bloc suspendu dans le vide, coffre posé sur un plancher et rempli, peintures adossées à un mur, pas de créature dans une maison ;
- pas de message « get_nodes_in_area: area too big » dans le chat ;
- tenir une tree star : les herbivores suivent.

Après la session : `grep -n "ERROR\|paleocave" ~/Library/Application\ Support/minetest/debug.txt | tail -50`.

## Lire une erreur
`Runtime error from mod 'x'` donne le mod, et la pile `stack traceback` donne `fichier:ligne`. Remonter jusqu'au premier fichier de paleocave. Une erreur dans `on_generated` n'apparaît qu'à la génération (`smoke_test.sh`), pas au chargement.

## Compte rendu
Dire exactement ce qui a tourné (lint ? chargement ? génération ? en jeu ?) en recopiant les vraies sorties, avec quels mods (vrais ou remplaçants), et ce qui reste à tester en jeu.

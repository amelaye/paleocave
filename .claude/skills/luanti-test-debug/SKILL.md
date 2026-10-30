---
name: luanti-test-debug
description: Teste et débogue le mod paleocave - vérification syntaxique avec luajit, test hors moteur dans le scratchpad, test dans le jeu existant via un monde jetable (worldmods), lecture du log Luanti. À utiliser après toute modification ou quand quelque chose plante.
---

# Tester paleocave

Ne rien installer ni télécharger (Luanti, luacheck...) sans accord explicite.

## 1. Syntaxe (toujours, rapide)
`luajit` est disponible sur la machine :
```bash
for f in init.lua src/*.lua; do luajit -bl "$f" >/dev/null || echo "ERREUR $f"; done
```

## 2. Test hors moteur (scratchpad)
Pour la logique pure (géométrie de `src/caves.lua`, passes de `src/mapgen.lua`, placement des créatures) : un petit harnais luajit dans le scratchpad qui simule `core` (bruits, VoxelManip en mémoire, `PcgRandom`), charge `init.lua`, appelle les `on_generated` enregistrés sur quelques mapchunks entre -2000 et -5000, puis vérifie : aucune erreur, eau jamais en contact latéral ou par en dessous avec l'air, présence d'ambre, de plantes et de vignes, et part du sol éclairé (propagation de lumière simulée). Ne pas placer ce harnais dans le projet.

## 3. Test dans le jeu (sur accord explicite, Luanti installé)
Script `.claude/skills/luanti-test-debug/scripts/smoke_test.sh` : il crée un monde jetable pour le jeu existant (`GAMEID=...`), y lie le mod via `worldmods/paleocave`, démarre un serveur headless, puis classe le log (`ERROR`, `WARNING`, `deprecated`).
```bash
GAMEID=<id_du_jeu> bash .claude/skills/luanti-test-debug/scripts/smoke_test.sh
```

## 4. Test manuel à proposer
Monde neuf, créatif, `/grant singleplayer all`, puis `/teleport 0 -2110 0` (le premier niveau commence vers -2100) :
- cavernes, mers, ambre lumineux, vignes, arbres, peintures rupestres ;
- les dinosaures sont déjà là à l'arrivée (placés à la génération), les marins dans l'eau seulement ;
- creuser de l'ambre avec moustique → passer le moustique dans l'analyseur de fossiles → ADN → cultivateur → œuf ;
- tenir une tree star : les herbivores suivent.

## Lire une erreur
`Runtime error from mod 'x'` donne le mod, et la pile `stack traceback` donne `fichier:ligne`. Remonter jusqu'au premier fichier de paleocave.

## Compte rendu
Dire exactement ce qui a tourné (syntaxe ? harnais ? moteur ?) et ce qui reste à tester en jeu.

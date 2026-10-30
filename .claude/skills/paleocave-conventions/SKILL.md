---
name: paleocave-conventions
description: Contexte et règles du mod Luanti "paleocave" - UN seul mod (à la racine du dossier) à intégrer dans un jeu existant basé sur Minetest Game avec PaleoTest, mobkit, mob_core et d'autres mods. Nommage, dépendances, faits clés sur PaleoTest, ce qu'il ne faut jamais créer. À charger avant toute modification du mod.
---

# Paleocave - conventions

**paleocave est UN mod**, pas un jeu. Ses fichiers sont à la racine du dossier du projet. Il se copie (ou se lie) sous le nom `paleocave` dans le dossier `mods/` du jeu. Ce jeu existe déjà ailleurs : il est basé sur Minetest Game et contient déjà PaleoTest, mobkit, mob_core et d'autres mods.

## Ne jamais créer
- de structure de jeu ou de modpack (`game.conf`, `mods/`, `modpack.conf`, `mods.lock`) ;
- de copie des dépendances dans le projet. Pour lire leur code, les cloner dans le dossier temporaire (scratchpad) :
  `git clone --depth 1 https://github.com/ElCeejo/paleotest` (idem `ElCeejo/mob_core`, `TheTermos/mobkit`, `luanti-org/minetest_game`) ;
- d'outillage non demandé (frameworks de test, téléchargement ou installation de Luanti) : demander d'abord.

## Arborescence du mod
```
mod.conf  init.lua  settingtypes.txt  README.md
src/        caves.lua (géométrie partagée)  nodes.lua  crafts.lua  mapgen.lua  spawning.lua
textures/   paleocave_*.png
locale/     paleocave.fr.tr  template.txt
```
Un nouveau domaine = un nouveau fichier dans `src/`, chargé depuis `init.lua`. Pas de nouveau mod.

## Nommage et code
- Items et nœuds : `paleocave:<nom>`. Textures : `paleocave_<nom>.png`. Réglages : `paleocave_<nom>`.
- Une seule globale : la table `paleocave` (les sous-modules s'y rangent : `paleocave.caves`...).
- API `core.*`, tout en `local`, textes joueur via `paleocave.S("...")` + `locale/paleocave.fr.tr`.
- Dépendances : `depends = default, paleotest` ; `stairs` et `walls` en `optional_depends` (toujours tester `core.get_modpath`). N'appeler mobkit/mob_core directement que si nécessaire, et alors l'ajouter à `depends`.
- Être défensif face à la version de PaleoTest du jeu : vérifier `core.registered_entities[...]`, `core.registered_nodes[...]` et l'existence des fonctions avant usage.

## Faits clés sur PaleoTest (dépôt ElCeejo, 2020-2021, mobkit + mob_core)
- Créatures : dinosaures (brachiosaurus, carnotaurus, spinosaurus, stegosaurus, triceratops, tyrannosaurus, velociraptor), ptérosaures volants (pteranodon, quetzalcoatlus), sarcosuchus semi-aquatique, **marins** (dunkleosteus, mosasaurus, plesiosaurus : ils se débattent hors de l'eau), mammifères du Pléistocène.
- Listes construites au chargement : viande = nom avec meat/beef... + raw, ou groupe `food_meat_raw` ; herbivores = groupes `flora` (broutage) et `leaves` (brachiosaure) ; couveuse d'œufs = nœud avec `light_source >= 12` à proximité.
- `paleotest.fossil_analyzer.register_recipe(entrée, fonction)` est public : on peut ajouter une entrée qui rend de l'ADN (`paleotest:dna_<espèce>`).
- `paleotest.register_egg/register_syringe/register_embryo_sac` créent des items au préfixe `paleotest:` codé en dur : ne pas les appeler depuis paleocave.

## Contenu actuel du mod
Les cavernes primordiales (inspirées d'Alex's Caves) occupent la couche **-2000 à -5000** en 15 niveaux. Le mod ajoute le calcaire, l'ambre lumineux, la vigne archaïque, la tree star, les peintures rupestres et des créatures PaleoTest **placées dès la génération des cavernes** (elles doivent déjà être là quand on arrive). La géométrie (sol, plafond, niveau de la mer de chaque niveau) est définie une seule fois dans `src/caves.lua`.

---
name: paleotest-creature
description: Travaille sur les créatures PaleoTest dans le mod paleocave - apparition dans les cavernes primordiales (terrestres, rivage, marines, volantes), équilibrage des groupes et des plafonds, ou nouvelle espèce basée sur l'API PaleoTest/mobkit/mob_core. À utiliser pour tout dinosaure, reptile marin ou volant.
argument-hint: <espèce> [terre|rivage|eau|air]
---

# Créatures PaleoTest dans paleocave

Charger `paleocave-conventions`. Lire le code de PaleoTest dans une copie du scratchpad (`git clone --depth 1 https://github.com/ElCeejo/paleotest`), jamais dans le projet.

## Où vivent les créatures
La table `species` de `src/spawning.lua` décrit chaque créature : `where` (`land`, `shore`, `water`, `air`), `weight`, `group = {min, max}`, `room` (hauteur libre ou profondeur d'eau nécessaire, en nœuds), `max` (nombre maximal au même endroit), `width` (rayon de terrain plat, ou d'eau libre pour les marins). `paleocave.creatures.choose(spot, counts, random, fits)` choisit l'espèce.

**Les créatures sont placées à la génération** (exigence du projet : elles sont déjà là quand on arrive) :
- `populate()` dans `src/mapgen.lua` fait environ `11 × paleocave_dinosaur_density` essais par niveau et par mapchunk, sur les colonnes dont le sol est dans le mapchunk (pas de doublon). Il vérifie le terrain dans les données VoxelManip (sol, hauteur libre, eau, arbres), puis `core.after(0, creatures.add, liste)` ajoute les entités une fois le mapchunk écrit. Loin des joueurs, elles sont stockées dans la carte.
- **Créatures marines** (mosasaurus, plesiosaurus, dunkleosteus) : uniquement dans une vraie mer (eau libre autour, `width`), assez profonde (`room`), boîte de collision entièrement sous la surface.
- Hauteur de placement à terre : `y = sol + 0.6 - collisionbox[2]`, avec la boîte lue dans `core.registered_entities[nom]`.
- Tailles adultes (boîtes de collision) : brachiosaure 4,8 × 5,25 (il lui faut 8 de haut et du large), tyrannosaure/stégosaure/tricératops ~2,5 de haut, mosasaure 3,6 × 2,8 (il évite le fond et la surface de 4 nœuds), les ptérosaures planent à environ 12 au-dessus du sol (16 de plafond minimum).
- Repeuplement autour des joueurs : en option (`paleocave_repopulate`, désactivé par défaut), avec un plafond `paleocave_max_dinosaurs` dans un rayon de 72.
- Performance : environ 15 créatures par zone de 80 × 80 colonnes de caverne, soit 20 à 30 actives autour d'un joueur. Rester prudent avant d'augmenter.

## Nouvelle espèce (dans paleocave)
1. Copier le schéma du modèle PaleoTest le plus proche (`mobs/smilodon.lua`, `mammoth.lua`, `mosasaurus.lua`, `pteranodon.lua`) dans `src/creatures/<espèce>.lua`, avec le nom `paleocave:<espèce>`.
2. Champs obligatoires pour être reconnue par PaleoTest : `get_staticdata = mobkit.statfunc`, `logic = ...`, `on_activate = paleotest.on_activate`, `on_step = paleotest.on_step` → ajouter `mobkit` et `mob_core` à `depends`.
3. Logique : bloc `if mobkit.timer(self, 1)` puis priorités décroissantes (`prty < N`). Tout parcours d'entités (`core.luaentities`) doit rester dans ce bloc pour les performances.
4. Résurrection : **ne pas appeler** `paleotest.register_egg/syringe/embryo_sac` (préfixe `paleotest:` codé en dur → erreur de nommage). Écrire un équivalent `paleocave:egg_<espèce>` inspiré de `api/register.lua` (code GPL-3.0 : créditer ElCeejo), puis brancher `paleotest.dna_cultivator.register_recipe(adn, œuf)` et une source d'ADN via `paleotest.fossil_analyzer.register_recipe` (comme le moustique dans l'ambre).
5. L'ajouter à la table `species` de `src/spawning.lua` : elle sera alors placée à la génération.

## Vérifier
Œuf de spawn mob_core en créatif, puis observer : déplacement, sommeil, attaque, mort et drops, et comportement dans l'eau pour les espèces marines. Ne pas affirmer qu'un test a eu lieu s'il n'a pas tourné.

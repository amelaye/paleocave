---
name: luanti-mod-integration
description: Fait cohabiter le mod paleocave avec le jeu existant (Minetest Game, PaleoTest, mobkit, mob_core et les autres mods du jeu) - dépendances, conflits de noms ou de recettes, autres générateurs de grottes aux mêmes profondeurs, différences de version de PaleoTest, APIs Luanti dépréciées. À utiliser quand paleocave plante dans le jeu ou entre en conflit avec un autre mod.
---

# Intégrer paleocave dans le jeu

Charger `paleocave-conventions`. On ne modifie que paleocave, jamais les autres mods du jeu.

## Diagnostic
1. Demander (ou lire) le log Luanti (`debug.txt`) : la première `ERROR` donne le mod et `fichier:ligne`.
2. Vérifier que le jeu contient bien les dépendances de `mod.conf` (`default`, `paleotest`) et le nom du dossier du mod (`paleocave`).
3. Comparer avec le code des autres mods dans une copie au scratchpad si besoin.

## Conflits possibles et réponses côté paleocave
| Symptôme | Cause | Réponse |
|---|---|---|
| `unknown node/item paleotest:...` | version de PaleoTest différente | tester `core.registered_*` avant usage, prévoir un repli |
| deux mods génèrent des grottes vers -2000/-5000 (caverealms, everness...) | `on_generated` concurrents | le signaler ; éventuellement rendre `caves.TOP/BOTTOM` configurables |
| mêmes recettes, deux résultats | recettes en conflit | changer la recette de paleocave |
| lag | trop de créatures actives, ABM trop fréquent | baisser `paleocave_dinosaur_density` (nouvelles zones seulement), revoir `interval/chance` des ABM |
| nom déjà pris | autre mod au même nom de nœud | nos noms sont tous préfixés `paleocave:`, vérifier les `subname` d'escaliers |

## Versions
PaleoTest (2020-21), mob_core et mobkit sont anciens. Pour repérer les dépréciations : `deprecated_lua_api_handling = log` dans `minetest.conf`, puis chercher `deprecated` dans le log. Dans paleocave, toujours prévoir le repli entre ancien et nouveau nom d'API (ex. `core.get_value_noise_map or core.get_perlin_map`).

## Livrable
Cause, correctif dans paleocave, fichier(s) touchés, comment vérifier en jeu, et si le problème vient d'un autre mod (à signaler à son auteur plutôt qu'à corriger).

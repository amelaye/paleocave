# Paleocave — cavernes primordiales

Mod Luanti inspiré des *Primordial Caves* d'Alex's Caves, construit avec le contenu de **PaleoTest**.
Entre **-2000 et -5000**, le sous-sol abrite des cavernes géantes éclairées par l'ambre, couvertes de végétation préhistorique, creusées de mers souterraines et peuplées de dinosaures.

## Installation
1. Copier (ou lier) ce dossier dans le dossier `mods/` du jeu sous le nom **`paleocave`**.
2. Le jeu doit contenir `default` (Minetest Game) et `paleotest`, ainsi que les dépendances de PaleoTest (`mobkit`, `mob_core`, `stairs`, `walls`).
3. Facultatif mais conseillé : **moreblocks**. Les ruines utilisent alors ses quarts de dalle, panneaux et micro-blocs pour des murs plus irréguliers, et ses formes s'ajoutent au calcaire, au bloc d'os et aux rondins de métaséquoia (scie circulaire). Sans moreblocks, les escaliers et dalles du mod `stairs` prennent le relais.
4. Activer le mod pour le monde.

Les cavernes n'apparaissent que dans les zones **pas encore générées**. Un monde neuf est le plus simple. Pour aller voir : `/teleport 0 -2110 0` (créatif conseillé).

## Contenu
- **Cavernes** : 15 niveaux empilés tous les 200 nœuds environ, de -2120 à -4894. Chacun a son sol vallonné, son plafond (souvent 15 à 40 nœuds au-dessus du sol), ses piliers et ses **mers souterraines** (jusqu'à une quarantaine de nœuds de profondeur). Le mod fonctionne avec tous les générateurs de carte qui remplissent le sous-sol de pierre, sauf `singlenode`.
- **Calcaire** (+ briques, escaliers, dalles, muret). Les minerais et les blocs fossiles de PaleoTest restent visibles dans les parois.
- **Ambre** (lumière 13) : grappes au plafond, cristaux au sol, inclusions dans les parois, fond des mers et flèches qui sortent de l'eau. C'est aussi une source de chaleur pour faire éclore les œufs de PaleoTest.
- **Ambre avec moustique** (1 ambre sur 12) : il donne un *moustique dans l'ambre*. Passé dans l'**analyseur de fossiles** de PaleoTest, il rend de l'ADN de dinosaure, de ptérosaure ou de reptile marin (7 fois sur 10). L'ADN passe ensuite au cultivateur pour obtenir l'œuf ou le sac embryonnaire.
- **Flore** : herbe primordiale, fougères, cycas et prêles de PaleoTest, métaséquoias, **vignes archaïques** (on peut y grimper) et **feuilles-étoiles**. Les herbivores suivent la personne qui tient une feuille-étoile et s'apprivoisent avec. La végétation broutée repousse lentement.
- **Peintures rupestres** : tyrannosaure, tricératops, brachiosaure, mosasaure.
- **Ruines primordiales**, inspirées des *Caveman Houses* d'Alex's Caves : une à trois maisons en ruine sur un terrain aplani, environ un site pour trois mapchunks de caverne (80 × 80).
  - murs de briques de calcaire effondrés de façon irrégulière : sommets en escaliers et en dalles, brèches, gravats tout autour ;
  - matériaux de PaleoTest : poteaux d'angle, poutres et linteaux en rondins de métaséquoia, plancher d'étage en planches (en partie effondré), parfois un étage entier en colombage ; quelques blocs de fossiles et des os pris dans les murs ;
  - à l'intérieur : escalier vers l'étage, peintures rupestres, lampes d'ambre, un tas d'os avec parfois un crâne, des plantes qui poussent à travers le sol ;
  - un **coffre** (à l'étage quand il y en a un) : viande de dinosaure cuite, charbon, silex, épée en pierre, ambre, et parfois un fossile ou un moustique dans l'ambre.
- **Squelettes** en blocs d'os, environ un pour quatre mapchunks de caverne :
  - dinosaures couchés et à moitié enterrés : colonne vertébrale qui descend vers la queue et le crâne, côtes en arceaux, pattes écartées, griffes et dents en micro-blocs, quelques os éparpillés (deux tailles) ;
  - reptiles marins au fond des mers : mosasaure (longue queue, longues mâchoires) et plésiosaure (long cou, nageoires).
- **Bloc d'os** (à poser debout ou couché, avec ses escaliers et dalles) : dans les ruines et les squelettes, ou fabriqué avec les ossements (`bones:bones`) que donnent les blocs de fossiles.
- **Créatures déjà présentes** : elles sont placées en même temps que la génération des cavernes, environ 15 par zone de 80 × 80 nœuds. Loin des joueurs, elles restent enregistrées dans la carte et s'animent quand quelqu'un approche.
  - sur la terre ferme : vélociraptor, stégosaure, tricératops, carnotaure, tyrannosaure, brachiosaure (seulement là où il a la place) ;
  - sur les rivages ou en eau peu profonde : sarcosuchus, spinosaure ;
  - **dans l'eau uniquement**, et seulement dans de vraies mers, pas dans les mares : plésiosaure, dunkleosteus, mosasaure (au moins 10 nœuds de profondeur) ;
  - sous les hauts plafonds : ptéranodon, quetzalcoatlus.

  Les créatures tuées ne reviennent pas, sauf si le repeuplement est activé.

## Réglages
| Réglage | Défaut | Rôle |
|---|---|---|
| `paleocave_dinosaurs` | `true` | place les créatures à la génération des cavernes |
| `paleocave_dinosaur_density` | `1` | multiplicateur du nombre de créatures (2 = deux fois plus) |
| `paleocave_repopulate` | `false` | fait aussi apparaître de nouvelles créatures autour des joueurs |
| `paleocave_max_dinosaurs` | `14` | repeuplement : créatures sauvages maximum dans un rayon de 72 nœuds |
| `paleocave_spawn_interval` | `30` | repeuplement : secondes entre deux tentatives |
| `paleocave_ruins` | `true` | génère les ruines primordiales |
| `paleocave_skeletons` | `true` | génère les squelettes de dinosaures et de reptiles marins |

## Limites connues
- Un autre mod qui génère des grottes entre -2000 et -5000 peut se superposer aux cavernes.
- Les ruines et les squelettes, comme les cavernes, n'apparaissent que dans les zones générées après l'installation (ou la mise à jour) du mod.
- Les créatures sont celles de PaleoTest : leur comportement (faim, attaques, sommeil) vient de ce mod.
- Une densité élevée met beaucoup de créatures PaleoTest actives autour de chaque joueur, ce qui peut ralentir un serveur modeste.

## Licences
- Code : GPL-3.0-or-later, comme PaleoTest dont il dépend.
- Textures `textures/paleocave_*.png` (bloc d'os compris) : CC BY-SA 4.0, amelaye. Elles se combinent avec `default_dirt.png` de Minetest Game (CC BY-SA 3.0).

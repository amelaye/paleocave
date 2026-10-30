# Paleocave — cavernes primordiales

Mod Luanti inspiré des *Primordial Caves* d'Alex's Caves, construit avec le contenu de **PaleoTest**.
Entre **-2000 et -5000**, le sous-sol abrite des cavernes géantes éclairées par l'ambersol, couvertes de végétation préhistorique, creusées de mers souterraines et peuplées de dinosaures.

## Installation
1. Copier (ou lier) ce dossier dans le dossier `mods/` du jeu sous le nom **`paleocave`**.
2. Le jeu doit contenir `default` (Minetest Game) et `paleotest`, ainsi que les dépendances de PaleoTest (`mobkit`, `mob_core`, `stairs`, `walls`).
3. Facultatif mais conseillé : **moreblocks**. Les ruines utilisent alors ses quarts de dalle, panneaux et micro-blocs pour des murs plus irréguliers, et ses formes s'ajoutent au calcaire, au bloc d'os et aux rondins de métaséquoia (scie circulaire). Sans moreblocks, les escaliers et dalles du mod `stairs` prennent le relais.
4. Activer le mod pour le monde.

Les cavernes n'apparaissent que dans les zones **pas encore générées**. Un monde neuf est le plus simple. Pour aller voir : `/paleocave` (privilège `teleport`) donne les coordonnées d'un sol hors de l'eau dans la caverne la plus proche, même très loin. Ensuite `/teleport <x> <y> <z>` (créatif conseillé).

## Contenu
- **Cavernes** : **5 dans tout le monde**, chacune large d'environ 500 nœuds (rayon 250) et à sa propre profondeur entre -2000 et -5000. Elles sont loin les unes des autres et toujours dans la carte, de -10000 à 10000 en x et en z. Leur position est choisie à partir de la graine du monde, puis enregistrée avec le monde. Chacune a son sol vallonné, son plafond (souvent 30 à 50 nœuds au-dessus du sol, assez pour un brachiosaure), ses **piliers de calcaire** ronds qui vont du sol au plafond, fins au milieu et plus de deux fois plus larges en bas et en haut et ses **mers souterraines** (jusqu'à une quarantaine de nœuds de profondeur). Le mod fonctionne avec tous les générateurs de carte qui remplissent le sous-sol de pierre, sauf `singlenode`.
- **Calcaire** (+ briques, escaliers, dalles, muret). Les minerais et les blocs fossiles de PaleoTest restent visibles dans les parois.
- **Ambre et ambersol**, comme dans Alex's Caves : de petites boules d'ambre translucide pendent du plafond, une tous les 40 nœuds environ, avec un **ambersol** (lumière maximale) au sommet de chacune. L'ambersol éclaire tout ce qui est en dessous grâce à une lumière invisible, jusqu'au sol ou à la surface de l'eau. L'ambre lui-même n'éclaire pas. L'ambersol est aussi une source de chaleur pour faire éclore les œufs de PaleoTest.
- **Flore** : herbe primordiale, fougères, cycas et prêles de PaleoTest, métaséquoias, **vignes archaïques** (on peut y grimper) et **feuilles-étoiles**. Les herbivores suivent la personne qui tient une feuille-étoile et s'apprivoisent avec. La végétation broutée repousse lentement.
- **Peintures rupestres** : tyrannosaure, tricératops, brachiosaure, mosasaure.
- **Ambiance sonore** de jungle, seulement dans les cavernes : les enregistrements s'enchaînent en fondu, avec grenouilles et grillons du marais près des mers souterraines. Le son s'éteint doucement quand on sort de la caverne.
- **Sans Everness** : si le jeu contient Everness, ses biomes souterrains (pierres, mousses, cristaux, plantes, structures) sont enlevés dans les cavernes et autour : creusés, ou changés en calcaire.
- **Ruines primordiales**, inspirées des *Caveman Houses* d'Alex's Caves : une à trois maisons en ruine sur un terrain aplani, environ un site pour trois mapchunks de caverne (80 × 80).
  - murs de briques de calcaire effondrés de façon irrégulière : sommets en escaliers et en dalles, brèches, gravats tout autour ;
  - matériaux de PaleoTest : poteaux d'angle, poutres et linteaux en rondins de métaséquoia, plancher d'étage en planches (en partie effondré), parfois un étage entier en colombage ; quelques blocs de fossiles et des os pris dans les murs ;
  - à l'intérieur : escalier vers l'étage, peintures rupestres, lampes d'ambersol, un tas d'os avec parfois un crâne, des plantes qui poussent à travers le sol ;
  - un **coffre** (à l'étage quand il y en a un) : viande de dinosaure cuite, charbon, silex, épée en pierre, ambre, et parfois un fossile.
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
- Dans un monde où la couche -2000 à -5000 a déjà été générée avec une ancienne version du mod (cavernes partout), ces cavernes restent : seules les nouvelles zones suivent la règle des 5 cavernes.
- Un autre mod qui génère des grottes entre -2000 et -5000 peut se superposer aux cavernes.
- Les ruines et les squelettes, comme les cavernes, n'apparaissent que dans les zones générées après l'installation (ou la mise à jour) du mod.
- Les créatures sont celles de PaleoTest : leur comportement (faim, attaques, sommeil) vient de ce mod.
- mobkit (utilisé par PaleoTest) écrit « get_nodes_in_area: area too big » dans le chat quand une créature vérifie un pas trop grand. Paleocave remplace cette fonction de mobkit par la même, sans le message (`src/compat.lua`).
- Une densité élevée met beaucoup de créatures PaleoTest actives autour de chaque joueur, ce qui peut ralentir un serveur modeste.

## Licences
- Code : GPL-3.0-or-later, comme PaleoTest dont il dépend.
- Textures `textures/paleocave_*.png` (bloc d'os compris) : CC BY-SA 4.0, amelaye. Elles se combinent avec `default_dirt.png` de Minetest Game (CC BY-SA 3.0).
- Sons `sounds/paleocave_jungle*.ogg` : CC0 1.0 (domaine public), aperçus OGG haute qualité tirés de Freesound :
  - `paleocave_jungle.1.ogg` : *Jungle, Tropical birds and insects*, myrinvp, https://freesound.org/s/423711/
  - `paleocave_jungle.2.ogg` : *Peruvian Amazon birds frogs daytime*, nonamethefish, https://freesound.org/s/653743/
  - `paleocave_jungle.3.ogg` : *Bako National Park, Borneo Island, Rain Forest Ambience daytime*, gladkiy, https://freesound.org/s/333225/
  - `paleocave_jungle_swamp.ogg` : *Frogs croaking & crickets at night in jungle swamp Africa*, mycompasstv, https://freesound.org/s/462889/
  - `paleocave_jungle_waterfall.ogg` : *Thailand Phangan Jungle Waterfall 1*, Archos, https://freesound.org/s/468242/

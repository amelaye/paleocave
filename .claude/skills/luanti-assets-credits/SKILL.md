---
name: luanti-assets-credits
description: Gère les médias du mod paleocave (textures 16x16, sons, modèles, traductions) et la section crédits/licences du README. À utiliser pour ajouter ou renommer une texture, trouver une texture manquante, mettre à jour les traductions ou les crédits.
---

# Médias et crédits

Charger `paleocave-conventions`.

## Formats
- **Textures** : PNG 16x16 comme Minetest Game, dans `textures/`, nom `paleocave_<nom>.png` (les noms de médias sont globaux à tout le jeu). Les textures transparentes (plantes, peintures, ambre) sont en RGBA.
- On peut composer avec les textures de MTG : `"default_dirt.png^paleocave_primordial_grass_side.png"`.
- **Sons** : OGG mono, `paleocave_<nom>.ogg`, variantes `.1.ogg`, `.2.ogg`.
- **Modèles** : `.b3d` ou `.obj` dans `models/` (créer le dossier seulement si besoin).

## Textures manquantes ou orphelines
```bash
grep -rhoE 'paleocave_[a-z0-9_]+\.png' init.lua src | sort -u | while read -r t; do
	[ -f "textures/$t" ] || echo "MANQUANT : $t"
done
for f in textures/*.png; do
	grep -rq "$(basename "$f")" init.lua src || echo "ORPHELINE ? $f"
done
```
Les noms construits dynamiquement (`"paleocave_cave_painting_" .. name .. ".png"`) échappent au grep : vérifier à la main.

## Traductions
`locale/paleocave.fr.tr` : en-tête `# textdomain: paleocave`, lignes `Source anglaise=Traduction` (`@=` pour `=`, `@n` pour un saut de ligne, `@1` pour un paramètre). `locale/template.txt` contient les mêmes clés avec des valeurs vides.

## Crédits
Section « Licences » du `README.md` : licence du code, auteur et licence de chaque média. Pour tout média qui ne vient pas du projet, noter l'URL d'origine et la licence. Refuser un média sans licence claire et le signaler.

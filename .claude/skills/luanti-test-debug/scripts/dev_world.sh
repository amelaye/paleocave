#!/usr/bin/env bash
# Prépare le test en jeu du mod :
#   1. lien symbolique <user>/mods/paleocave -> ce dossier (le code est lu en direct, pas de copie) ;
#   2. monde dédié <user>/worlds/paleocave_dev (créatif) avec le mod, les mods de
#      .claude/test_mods.txt et ceux de EXTRA_WORLDMODS (liés dans son worldmods/) ;
#   3. avec --launch : ouvre Luanti directement dans ce monde.
# Options : --new    supprime puis recrée le monde de dev (indispensable après une modif du générateur :
#                    les chunks déjà générés ne sont jamais regénérés)
#           --launch lance Luanti dans le monde de dev (ouvre une fenêtre : seulement à la demande)
# Ne modifie JAMAIS les autres mondes. Refuse d'écraser un vrai dossier <user>/mods/paleocave.
#
# Usage : .claude/skills/luanti-test-debug/scripts/dev_world.sh [--new] [--launch]

set -euo pipefail
. "$(dirname "$0")/lib.sh"

LINK="$USER_DIR/mods/$MODNAME"
WORLD="$USER_DIR/worlds/${MODNAME}_dev"

NEW=0; LAUNCH=0
for a in "$@"; do
	case "$a" in
		--new) NEW=1 ;;
		--launch) LAUNCH=1 ;;
		*) echo "Option inconnue : $a"; exit 1 ;;
	esac
done

mkdir -p "$USER_DIR/mods" "$USER_DIR/worlds"

# 1. Lien du mod
if [ -L "$LINK" ]; then
	[ "$(readlink "$LINK")" != "$MOD_DIR" ] && ln -sfn "$MOD_DIR" "$LINK"
	echo "Lien OK      : $LINK -> $MOD_DIR"
elif [ -e "$LINK" ]; then
	echo "ERREUR : $LINK existe déjà et n'est pas un lien. Déplace-le puis relance."; exit 1
else
	ln -s "$MOD_DIR" "$LINK"; echo "Lien créé    : $LINK -> $MOD_DIR"
fi

# 2. Monde de dev
if [ "$NEW" = 1 ] && [ -d "$WORLD" ]; then
	case "$WORLD" in *"/worlds/${MODNAME}_dev") rm -rf "$WORLD"; echo "Monde supprimé : $WORLD" ;; esac
fi
if [ ! -f "$WORLD/world.mt" ]; then
	make_world "$WORLD" true
	# le mod est pris dans <user>/mods (lien ci-dessus), pas en double dans worldmods/
	rm -f "$WORLD/worldmods/$MODNAME"
	echo "load_mod_$MODNAME = true" >> "$WORLD/world.mt"
	echo "Monde créé   : $WORLD"
else
	echo "Monde OK     : $WORLD"
	for m in "$MODNAME" $(test_mods); do
		[ -L "$WORLD/worldmods/$m" ] && continue
		if grep -q "^load_mod_$m *=" "$WORLD/world.mt"; then
			sed -i '' "s/^load_mod_$m *=.*/load_mod_$m = true/" "$WORLD/world.mt"
		else
			echo "load_mod_$m = true" >> "$WORLD/world.mt"
		fi
	done
fi
missing="$(missing_mods)"
[ -n "$missing" ] && echo "ATTENTION    : mods introuvables (à installer ou à passer par EXTRA_WORLDMODS) : $(echo $missing)"
echo "Mods activés : $MODNAME $(test_mods | tr '\n' ' ')"

# 3. Lancement
if [ "$LAUNCH" = 1 ]; then
	BIN="$(find_luanti)" || { echo "ERREUR : binaire Luanti introuvable (définir LUANTI_BIN)."; exit 1; }
	nohup "$BIN" --go --world "$WORLD" --name dev >/dev/null 2>&1 &
	echo "Luanti lancé dans le monde ${MODNAME}_dev (log : $USER_DIR/debug.txt)"
fi

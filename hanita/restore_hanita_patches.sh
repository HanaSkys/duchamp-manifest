#!/bin/bash
# Hanita Mods: vuelve a aplicar los 3 parches que viven en repos de crDroid.
# Son solo para las builds de desarrollo (userdebug con adb root); el
# comportamiento de una build pública no cambia.
#   build/make   - PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG solo cuenta si vale "true"
#   build/soong  - gen_build_prop vuelve a reportar userdebug si el producto es depurable
#   system/core  - init no aplica el "spoof" de SafetyNet en builds depurables
# Cada parche queda en una rama hanita-keep y respaldado en ~/hanita-patches.
# Uso: ./restore_hanita_patches.sh ~/crDroid
set -euo pipefail
TOP=$(readlink -f "${1:?ruta al árbol de crDroid}")
OUT="$HOME/hanita-patches"
mkdir -p "$OUT"

apply() {  # repo  archivo  mensaje-de-commit  nombre-respaldo  (viejo/nuevo por stdin, separados)
    local repo=$1 file=$2 msg=$3 name=$4
    local dir="$TOP/$repo"
    [ -d "$dir/.git" ] || [ -f "$dir/.git" ] || { echo "No existe $dir"; exit 1; }
    if git -C "$dir" log --oneline -20 | grep -qF "$msg"; then
        echo "== $repo: ya estaba aplicado"; return
    fi
    [ -z "$(git -C "$dir" status --porcelain -- "$file")" ] || { echo "$repo/$file tiene cambios sin guardar; revísalo"; exit 1; }
    python3 - "$dir/$file" <<PY
import sys
p = sys.argv[1]
s = open(p).read()
old, new = open("$OLDF").read(), open("$NEWF").read()
if s.count(old) != 1:
    sys.exit(f"{p}: el código cambió en crDroid y no tiene la forma esperada; no se aplicó nada. Pásale la salida a Claude.")
open(p, "w").write(s.replace(old, new))
PY
    local up
    up=$(git -C "$dir" for-each-ref --format='%(refname:short)' refs/remotes | grep '/17.0$' | grep -v '^m/' | head -1)
    git -C "$dir" checkout -q -B hanita-keep
    [ -n "$up" ] && { git -C "$dir" branch -q --set-upstream-to="$up" 2>/dev/null || echo "   (aviso: no se pudo enlazar hanita-keep con $up; no afecta al parche)"; }
    git -C "$dir" commit -q -am "$msg"
    git -C "$dir" format-patch -q -1 HEAD -o "$OUT/$name"
    echo "== $repo: aplicado ($(git -C "$dir" log --oneline -1)) · upstream: ${up:-ninguno}"
}

T=$(mktemp -d); OLDF=$T/old; NEWF=$T/new

# 1) build/make
cat > $OLDF <<'EOF'
$(call add_json_bool, ProductNotDebuggableInUserdebug, $(PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG))
EOF
cat > $NEWF <<'EOF'
$(call add_json_bool, ProductNotDebuggableInUserdebug, $(filter true,$(PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG)))
EOF
apply build/make core/soong_extra_config.mk \
    "soong_extra_config: only treat PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG=true as set" build_make

# 2) build/soong
cat > $OLDF <<'EOF'
  if product_config["Eng"]:
    return "eng"
  else:
    return "user"
EOF
cat > $NEWF <<'EOF'
  if product_config["Eng"]:
    return "eng"
  elif product_config.get("Debuggable") and not product_config.get("ProductNotDebuggableInUserdebug"):
    return "userdebug"
  else:
    return "user"
EOF
apply build/soong scripts/gen_build_prop.py \
    "gen_build_prop: report userdebug when the product keeps it debuggable" build_soong

# 3) system/core
cat > $OLDF <<'EOF'
static void SetSafetyNetProps() {
EOF
cat > $NEWF <<'EOF'
static void SetSafetyNetProps() {
    // Hanita: keep development (debuggable) builds debuggable: adb root and rooted debugging.
    if (android::base::GetBoolProperty("ro.debuggable", false)) {
        LOG(INFO) << "SetSafetyNetProps: skipped on a debuggable build";
        return;
    }
EOF
apply system/core init/property_service.cpp \
    "init: skip SafetyNet prop spoofing on debuggable builds" system_core

rm -rf "$T"
echo; echo "Respaldo en $OUT:"; ls -R "$OUT" | grep patch

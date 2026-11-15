# duchamp-manifest · crDroid A17 (Hanita Mods)

Todo lo necesario para rehacer desde cero el árbol de crDroid 17 para el Poco X6 Pro
(duchamp) con los cambios de HanaSkys.

## 1. Bajar el código
```bash
mkdir -p ~/crDroid && cd ~/crDroid
repo init -u https://github.com/crdroidandroid/android.git -b 17.0 --git-lfs --no-clone-bundle
git clone https://github.com/HanaSkys/duchamp-manifest /tmp/dm
mkdir -p .repo/local_manifests && cp /tmp/dm/local_manifests/duchamp.xml .repo/local_manifests/
repo sync -c --force-sync --no-tags --no-clone-bundle -j$(nproc)
```

## 2. Parches en repos de crDroid
Tres cambios pequeños para que las builds `userdebug` sigan siendo depurables (adb root):

| Repo | Cambio |
|---|---|
| `build/make` | `PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG` solo cuenta si vale `true` |
| `build/soong` | `gen_build_prop.py` vuelve a reportar `userdebug` |
| `system/core` | init no aplica el "spoof" de SafetyNet en builds depurables |

```bash
/tmp/dm/hanita/restore_hanita_patches.sh ~/crDroid
```
El script revisa que el código de crDroid tenga la forma esperada; si cambió, no aplica nada
y avisa. Cada parche queda en una rama `hanita-keep` (repo sync la rebasa sobre crDroid).
En `hanita/patches/` están los mismos cambios en formato `git format-patch`, como referencia.

> Builds públicas: quitar `PRODUCT_NOT_DEBUGGABLE_IN_USERDEBUG := false` de
> `lineage_duchamp.mk`, o Play Integrity y apps de bancos pueden fallar.

## 3. Compilar (siempre dentro de tmux)
```bash
tmux new -s build
cd ~/crDroid && source build/envsetup.sh
brunch duchamp userdebug 2>&1 | tee ~/build.log
```
`Ctrl+B` y luego `D` para salir sin detenerla; `tmux attach -t build` para volver.
Para detenerla: `Ctrl+C` (nunca `Ctrl+Z`).

## Repos de HanaSkys
- `android_device_xiaomi_duchamp` (crdroid-a17): device tree, Hanita Mods, Game Space
- `vendor_xiaomi_duchamp` (crdroid-a17): blobs
- `device_xiaomi_duchamp-kernel` (crdroid-a17): kernel precompilado
- `android_device_mediatek_sepolicy_vndr`, `vendor_xiaomi_duchamp-miuicamera`
- Fuentes del kernel: `kernel_manifest` (lineage-23.2) → `android_kernel_6.1`,
  `android_kernel_device_modules_6.1`, `android_vendor_mediatek_kernel_modules`

#!/usr/bin/env bash
# arch-config-backup.sh — posbírá konfiguraci Arch systému do složky připravené pro git.
#
# Co sbírá:
#   packages/pkglist.txt   explicitně nainstalované balíčky z oficiálních repozitářů
#   packages/aurlist.txt   balíčky z AUR / lokálně sestavené
#   services/system.txt    zapnuté systemd služby
#   services/user.txt      zapnuté uživatelské systemd služby
#   etc/...                upravené configy balíčků + vlastní soubory v /etc (bez citlivých)
#   boot/loader/...        konfigurace systemd-boot (pokud existuje)
#   REVIEW.txt             soubory přeskočené kvůli podezřelému obsahu (heslo, token, klíč)
#
# Použití:  ./arch-config-backup.sh [cílová_složka]      (výchozí: ~/arch-config)
# Lze spouštět opakovaně: složky etc/, boot/, packages/, services/ se pokaždé vytvoří znovu.

set -euo pipefail

OUT="$(realpath -m "${1:-$HOME/arch-config}")"
case "$OUT" in
  / | /etc | /etc/* | /boot | /boot/* | "$HOME")
    echo "Nebezpečná cílová složka: $OUT" >&2
    exit 1
    ;;
esac

# --- Soubory, které se NIKDY nekopírují (tajné údaje) -------------------------
DENY_RE='^/etc/g?shadow-?$'
DENY_RE+='|^/etc/ssh/ssh_host_'
DENY_RE+='|^/etc/NetworkManager/system-connections/'
DENY_RE+='|^/etc/wireguard/|^/etc/openvpn/|^/etc/wpa_supplicant/|^/etc/iwd/'
DENY_RE+='|^/etc/pacman\.d/gnupg/|^/etc/machine-id$'
DENY_RE+='|^/etc/crypttab|^/etc/cryptsetup-keys\.d/'
DENY_RE+='|^/etc/sudoers'
DENY_RE+='|^/etc/ssl/private/|^/etc/samba/private/|^/etc/credstore'
DENY_RE+='|^/etc/ipsec\.secrets|^/etc/ppp/(chap|pap)-secrets'
DENY_RE+='|\.(key|pem|p12|pfx|keytab)$'

# --- Generovaný šum, který nemá smysl verzovat --------------------------------
NOISE_RE='^/etc/(passwd|group|subuid|subgid)-?$'
NOISE_RE+='|^/etc/(ld\.so\.cache|\.pwd\.lock|\.updated|adjtime|resolv\.conf|os-release)$'
NOISE_RE+='|^/etc/ssl/certs/|^/etc/ca-certificates/extracted/|^/etc/udev/hwdb\.bin$|^/etc/xml/catalog'
NOISE_RE+='|\.(pacnew|pacsave|bak|old|orig)$|~$'

# --- Podezřelý obsah: soubor se nezkopíruje, jen se zapíše do REVIEW.txt ------
SECRET_RE='(password|passwd|secret|token|api[_-]?key|private[_-]?key|psk|credentials?)[[:space:]]*[=:]|BEGIN [A-Z ]*PRIVATE KEY'

# --- Uživatelské configy (relativně k ~), které ovlivňují vzhled a chování -----
HOME_PATHS=(
  .zshrc .bashrc .bash_profile .gtkrc-2.0 .gitconfig
  .config/hypr .config/kitty .config/foot .config/rofi .config/fastfetch
  .config/cava .config/btop .config/fzf .config/sway .config/swaylock
  .config/gtk-3.0 .config/gtk-4.0 .config/nwg-look .config/qt5ct .config/qt6ct
  .config/xsettingsd .config/Thunar .config/xfce4 .config/menus
  .config/micro/settings.json .config/micro/bindings.json .config/micro/colorschemes
  .config/Code/User/settings.json .config/Code/User/keybindings.json
  .config/mimeapps.list .config/user-dirs.dirs .config/user-dirs.locale
  .local/state/noctalia/settings.toml
  .local/bin
  .fonts
)
HOME_EXCLUDE_RE='/backup-[^/]*/|\.bak(\.[0-9]+)?$|\.pred-[^/]*$|\.(orig|old|log)$|~$|/\.git/'
# git klony v ~ (oh-my-zsh, zsh pluginy) se nekopírují, jen se zapíše odkud jsou
GIT_CLONES=("$HOME/.oh-my-zsh" "$HOME"/zsh-*)

need() { command -v "$1" >/dev/null || { echo "Chybí příkaz: $1" >&2; exit 1; }; }
need pacman; need systemctl; need sudo; need comm

echo "==> sudo je potřeba kvůli čtení souborů v /etc a /boot"
sudo -v

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$OUT"
rm -rf "${OUT:?}/etc" "${OUT:?}/usr" "${OUT:?}/boot" "${OUT:?}/home" "${OUT:?}/packages" "${OUT:?}/services"
mkdir -p "$OUT/packages" "$OUT/services"

# --- 1. Balíčky ---------------------------------------------------------------
echo "==> Seznam balíčků"
pacman -Qqen > "$OUT/packages/pkglist.txt"
pacman -Qqem > "$OUT/packages/aurlist.txt" || true   # vrací 1, když žádné nejsou

# --- 2. Služby ----------------------------------------------------------------
echo "==> Zapnuté služby"
systemctl list-unit-files --state=enabled --no-legend | awk '{print $1}' \
  > "$OUT/services/system.txt"
systemctl --user list-unit-files --state=enabled --no-legend 2>/dev/null | awk '{print $1}' \
  > "$OUT/services/user.txt" || true
# lokální výjimky: služby uvedené v .services-exclude (ten je v .gitignore) se vynechají
if [[ -f "$OUT/.services-exclude" ]]; then
  for s in system user; do
    grep -vxFf "$OUT/.services-exclude" "$OUT/services/$s.txt" > "$TMP/svc" || true
    mv "$TMP/svc" "$OUT/services/$s.txt"
  done
fi

# --- 3. Soubory v /etc --------------------------------------------------------
echo "==> Hledám upravené a vlastní soubory v /etc"
# upravené soubory, které patří balíčkům
# (novější pacman: "/etc/fstab [modified]", starší: "MODIFIED	/etc/fstab")
sudo env LC_ALL=C pacman -Qii \
  | awk '/\[modified\]$/ {print $(NF-1)} /^MODIFIED[[:space:]]/ {print $2}' > "$TMP/modified"
# soubory, které nepatří žádnému balíčku (tvoje vlastní configy, unity, pravidla…)
pacman -Qlq | grep -E '^/(etc|usr/local)/' | sort -u > "$TMP/owned"
sudo find /etc /usr/local -xdev -type f | sort > "$TMP/all"
comm -23 "$TMP/all" "$TMP/owned" > "$TMP/unowned"

sort -u "$TMP/modified" "$TMP/unowned" > "$TMP/candidates"
: > "$TMP/flagged"
: > "$TMP/denied"

copied=0
while IFS= read -r f; do
  [[ -z "$f" ]] && continue
  [[ "$f" =~ $NOISE_RE ]] && continue
  if [[ "$f" =~ $DENY_RE ]]; then
    echo "$f" >> "$TMP/denied"
    continue
  fi
  if sudo grep -EiIq -- "$SECRET_RE" "$f" 2>/dev/null; then
    echo "$f" >> "$TMP/flagged"
    continue
  fi
  sudo cp --parents -p -- "$f" "$OUT/"
  copied=$((copied + 1))
done < "$TMP/candidates"

# --- 4. Bootloader (systemd-boot) ---------------------------------------------
if sudo test -d /boot/loader; then
  echo "==> Konfigurace systemd-boot"
  sudo find /boot/loader -maxdepth 2 -type f -name '*.conf' -print0 \
    | xargs -0 -r sudo cp --parents -p -t "$OUT/"
fi
# GRUB se zachytí přes /etc/default/grub v kroku 3.

# soubory zkopírované přes sudo přepiš na aktuálního uživatele
for d in "$OUT/etc" "$OUT/usr" "$OUT/boot"; do
  [[ -e "$d" ]] && sudo chown -R "$(id -u):$(id -g)" "$d"
done

# --- 5. Uživatelské configy (dotfiles) ----------------------------------------
echo "==> Uživatelské configy z ~"
home_copied=0
for p in "${HOME_PATHS[@]}"; do
  [[ -e "$HOME/$p" ]] || continue
  while IFS= read -r -d '' f; do
    rel="${f#"$HOME"/}"
    [[ "/$rel" =~ $HOME_EXCLUDE_RE ]] && continue
    if [[ "$rel" =~ \.(key|pem|p12|pfx|keytab)$ ]]; then
      echo "~/$rel" >> "$TMP/denied"
      continue
    fi
    if grep -EiIq -- "$SECRET_RE" "$f" 2>/dev/null; then
      echo "~/$rel" >> "$TMP/flagged"
      continue
    fi
    mkdir -p "$OUT/home/$(dirname "$rel")"
    cp -p -- "$f" "$OUT/home/$rel"
    home_copied=$((home_copied + 1))
  done < <(find "$HOME/$p" -type f -print0)
done

# osobní údaje uvnitř jinak bezpečných configů
noc="$OUT/home/.local/state/noctalia/settings.toml"
[[ -f "$noc" ]] && sed -i -E 's/^([[:space:]]*address[[:space:]]*=[[:space:]]*).*/\1""/' "$noc"

# git klony: jen seznam "cesta url" pro obnovu
for d in "${GIT_CLONES[@]}"; do
  [[ -d "$d/.git" ]] || continue
  printf '%s %s\n' "~/${d#"$HOME"/}" "$(git -C "$d" remote get-url origin 2>/dev/null)"
done > "$TMP/clones"
[[ -s "$TMP/clones" ]] && cp "$TMP/clones" "$OUT/home/git-clones.txt"

# --- 6. Report a pomocné soubory ----------------------------------------------
{
  echo "# Soubory přeskočené kvůli podezřelému obsahu (heslo/token/klíč)."
  echo "# Projdi je ručně. Pokud v nich nic tajného není, zkopíruj je sám:"
  echo "#   sudo cp --parents -p /etc/CESTA $OUT/ && sudo chown -R \$USER: $OUT/etc"
  echo
  cat "$TMP/flagged"
} > "$OUT/REVIEW.txt"

if [[ ! -f "$OUT/.gitignore" ]]; then
  printf '%s\n' 'REVIEW.txt' '.services-exclude' '*.pacnew' '*.pacsave' > "$OUT/.gitignore"
fi

if [[ ! -f "$OUT/README.md" ]]; then
  cat > "$OUT/README.md" <<'EOF'
# Arch config

Vygenerováno skriptem `arch-config-backup.sh`.

## Obnova na čistém Archu

```bash
sudo pacman -S --needed - < packages/pkglist.txt
paru -S --needed - < packages/aurlist.txt        # nebo yay
sudo cp -r --preserve=mode etc/. /etc/            # projdi si nejdřív, co přepisuješ!
sudo cp -r --preserve=mode usr/. /usr/
cp -r home/. ~/                                   # uživatelské configy
while read -r dir url; do git clone "$url" "${dir/#\~/$HOME}"; done < home/git-clones.txt
xargs -r sudo systemctl enable < services/system.txt
xargs -r systemctl --user enable < services/user.txt
```
EOF
fi

echo
echo "Hotovo → $OUT"
echo "  balíčků:            $(wc -l < "$OUT/packages/pkglist.txt") oficiálních, $(wc -l < "$OUT/packages/aurlist.txt") AUR"
echo "  služeb:             $(wc -l < "$OUT/services/system.txt") systémových, $(wc -l < "$OUT/services/user.txt") uživatelských"
echo "  souborů z /etc:     $copied"
echo "  souborů z ~:        $home_copied"
echo "  vynecháno (tajné):  $(wc -l < "$TMP/denied")"
echo "  k ručnímu projití:  $(wc -l < "$TMP/flagged")  → $OUT/REVIEW.txt"
echo
echo "Před pushem doporučuju:  gitleaks dir $OUT   (pacman -S gitleaks)"

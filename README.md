# Arch config

Konfigurace mého Arch Linuxu (Hyprland + Noctalia), vygenerovaná skriptem [`arch-config-backup.sh`](arch-config-backup.sh).

| Složka | Obsah |
|---|---|
| `packages/` | seznam balíčků (oficiální + AUR) |
| `services/` | zapnuté systemd služby |
| `etc/`, `usr/` | upravené systémové configy |
| `home/` | uživatelské configy (Hyprland, Noctalia, kitty, rofi, GTK, zsh…) |

## Kde najdu configy

Uživatelské configy jsou ve skryté složce [`home/.config/`](home/.config):

| Co | Soubor |
|---|---|
| **Hyprland** | [`hyprland.lua`](home/.config/hypr/hyprland.lua), [`hyprland-gui.lua`](home/.config/hypr/hyprland-gui.lua), [`hypridle.conf`](home/.config/hypr/hypridle.conf), [`hyprlock.conf`](home/.config/hypr/hyprlock.conf) |
| **Noctalia** (bar, widgety, téma) | [`settings.toml`](home/.local/state/noctalia/settings.toml) |
| **Terminál** | [kitty](home/.config/kitty/kitty.conf), [foot](home/.config/foot/foot.ini), [`.zshrc`](home/.zshrc), [fastfetch](home/.config/fastfetch) |
| **Launcher** | [rofi](home/.config/rofi) |
| **Vzhled** | [GTK 3](home/.config/gtk-3.0/settings.ini), [GTK 4](home/.config/gtk-4.0/settings.ini), [`.gtkrc-2.0`](home/.gtkrc-2.0), [Qt barvy](home/.config/qt6ct/colors) |
| **Zamykací obrazovka** | [swaylock](home/.config/swaylock/config), [`lock-screen`](home/.local/bin/lock-screen), [PAM](etc/pam.d/swaylock) |
| **Ostatní** | [btop](home/.config/btop/btop.conf), [cava](home/.config/cava/config), [micro](home/.config/micro/settings.json), [Thunar](home/.config/Thunar), [výchozí aplikace](home/.config/mimeapps.list) |
| **Systém** | [`pacman.conf`](etc/pacman.conf), [`mkinitcpio.conf`](etc/mkinitcpio.conf), [GRUB](etc/default/grub), [balíčky](packages/pkglist.txt), [služby](services/system.txt) |

Soubory s `noctalia` v názvu jsou barevná témata, která Noctalia generuje z tapety.

## Obnova na čistém Archu

```bash
sudo pacman -S --needed - < packages/pkglist.txt
yay -S --needed - < packages/aurlist.txt
while read -r dir url; do git clone "$url" "${dir/#\~/$HOME}"; done < home/git-clones.txt
cp -r home/. ~/                                   # uživatelské configy
sudo cp -r --preserve=mode etc/. /etc/            # projdi si nejdřív, co přepisuješ!
sudo cp -r --preserve=mode usr/. /usr/
xargs -r sudo systemctl enable < services/system.txt
xargs -r systemctl --user enable < services/user.txt
```

Tapety nejsou součástí repa – Noctalia je hledá v `~/Wallpapers`.

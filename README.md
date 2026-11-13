# Arch config

Konfigurace mého Arch Linuxu (Hyprland + Noctalia), vygenerovaná skriptem [`arch-config-backup.sh`](arch-config-backup.sh).

| Složka | Obsah |
|---|---|
| `packages/` | seznam balíčků (oficiální + AUR) |
| `services/` | zapnuté systemd služby |
| `etc/`, `usr/` | upravené systémové configy |
| `home/` | uživatelské configy (Hyprland, Noctalia, kitty, rofi, GTK, zsh…) |

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

# Arch config

Vygenerováno skriptem `arch-config-backup.sh`.

## Obnova na čistém Archu

```bash
sudo pacman -S --needed - < packages/pkglist.txt
paru -S --needed - < packages/aurlist.txt        # nebo yay
sudo cp -r --preserve=mode etc/. /etc/            # projdi si nejdřív, co přepisuješ!
xargs -r sudo systemctl enable < services/system.txt
xargs -r systemctl --user enable < services/user.txt
```

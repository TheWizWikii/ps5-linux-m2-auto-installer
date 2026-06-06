#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
    echo "Run as root"
    exit 1
fi

NVME_PART="/dev/nvme0n1p1"
NVME_MNT="/mnt/ubuntu_m2"

# Ricava il label della root corrente (es. ubuntu2604)
SRC_LABEL=$(blkid -s LABEL -o value "$(findmnt -n -o SOURCE /)")
NEW_LABEL="${SRC_LABEL:-PS5_ROOT}-m2"

echo "Sorgente: filesystem live /"
echo "Label sorgente: ${SRC_LABEL:-PS5_ROOT}"
echo "Label destinazione M.2: $NEW_LABEL"

# Trova la partizione EFI montata
EFI_DEV=$(findmnt -n -o SOURCE /boot/efi)
if [ -z "$EFI_DEV" ]; then
    echo "Errore: partizione EFI non trovata su /boot/efi"
    exit 1
fi
EFI_LABEL=$(blkid -s LABEL -o value "$EFI_DEV")
if [ -n "$EFI_LABEL" ]; then
    EFI_IDENTIFIER="LABEL=$EFI_LABEL"
else
    EFI_UUID=$(blkid -s UUID -o value "$EFI_DEV")
    EFI_IDENTIFIER="UUID=$EFI_UUID"
fi
echo "Partizione EFI: $EFI_DEV ($EFI_IDENTIFIER)"

if [ ! -b "$NVME_PART" ]; then
    echo "Errore: $NVME_PART non trovato."
    exit 1
fi

umount -l "$NVME_PART" 2>/dev/null || true

echo "Formattazione $NVME_PART come ext4 con label: $NEW_LABEL"
mkfs.ext4 -F -L "$NEW_LABEL" "$NVME_PART"

mkdir -p "$NVME_MNT"
mount "$NVME_PART" "$NVME_MNT"

echo "Copia del sistema live sull'M.2 (potrebbe volerci qualche minuto)..."
rsync -axHAX \
    --exclude=/proc \
    --exclude=/sys \
    --exclude=/dev \
    --exclude=/run \
    --exclude=/tmp \
    --exclude=/mnt \
    --exclude=/boot/efi \
    / "$NVME_MNT/"

# Ricrea le directory virtuali escluse (il kernel le popola a runtime)
mkdir -p "$NVME_MNT"/{proc,sys,dev,run,tmp,mnt}
chmod 1777 "$NVME_MNT/tmp"

echo "Generazione /etc/fstab..."
cat <<EOF > "$NVME_MNT/etc/fstab"
# /etc/fstab: static file system information.
#
# <file system>      <mount point>  <type>  <options>  <dump>  <pass>
LABEL=$NEW_LABEL     /              ext4    defaults   0       1
$EFI_IDENTIFIER      /boot/efi      vfat    defaults   0       1
EOF

echo "Smontaggio..."
umount "$NVME_MNT"
rmdir "$NVME_MNT" 2>/dev/null || true

echo ""
echo "Installazione completata."
echo "Modifica /boot/efi/cmdline.txt: sostituisci root=LABEL=${SRC_LABEL:-PS5_ROOT} con root=LABEL=$NEW_LABEL"

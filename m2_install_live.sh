#!/bin/bash
set -e

if [[ $EUID -ne 0 ]]; then
    echo "Error: Este script debe ejecutarse como root (usa sudo)."
    exit 1
fi

NVME_DISK="/dev/nvme0n1"
NVME_PART="/dev/nvme0n1p1"
NVME_MNT="/mnt/ubuntu_m2"

# 1. COMPROBACIÓN E INSTALACIÓN DE RSYNC
if ! command -v rsync &> /dev/null; then
    echo "Instalando rsync automáticamente..."
    apt update && apt install -y rsync
fi

# 2. DETECCIÓN Y CREACIÓN AUTOMÁTICA DE LA PARTICIÓN
if [ ! -b "$NVME_DISK" ]; then
    echo "Errore crítico: No se detecta ningún disco M.2 NVMe en $NVME_DISK"
    exit 1
fi

if [ ! -b "$NVME_PART" ]; then
    echo "La partición $NVME_PART no existe. Creándola automáticamente..."
    # Envía comandos automáticos a fdisk: g (tabla GPT), n (nueva part), defaults, w (guardar)
    (echo g; echo n; echo 1; echo ""; echo ""; echo w) | fdisk "$NVME_DISK"
    
    # Forzar al kernel a leer la nueva tabla de particiones
    partprobe "$NVME_DISK" 2>/dev/null || sleep 2
    
    if [ ! -b "$NVME_PART" ]; then
        echo "Error: No se pudo crear la partición $NVME_PART de forma automática."
        exit 1
    fi
    echo "Partición creada con éxito."
fi

# Ricava il label della root corrente (es. ubuntu2604)
SRC_LABEL=$(blkid -s LABEL -o value "$(findmnt -n -o SOURCE /)")
NEW_LABEL="${SRC_LABEL:-PS5_ROOT}-m2"

echo "Origen: filesystem live /"
echo "Label origen: ${SRC_LABEL:-PS5_ROOT}"
echo "Label destino M.2: $NEW_LABEL"

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
echo "Partición EFI encontrada: $EFI_DEV ($EFI_IDENTIFIER)"

# Asegurar que no esté montada antes de formatear
umount -l "$NVME_PART" 2>/dev/null || true

echo "Formateando $NVME_PART como ext4 con label: $NEW_LABEL"
mkfs.ext4 -F -L "$NEW_LABEL" "$NVME_PART"

mkdir -p "$NVME_MNT"
mount "$NVME_PART" "$NVME_MNT"

echo "Copiando el sistema live al M.2 (esto tardará unos minutos)..."
rsync -axHAX \
    --exclude=/proc \
    --exclude=/sys \
    --exclude=/dev \
    --exclude=/run \
    --exclude=/tmp \
    --exclude=/mnt \
    --exclude=/boot/efi \
    / "$NVME_MNT/"

# Ricrea le directory virtuali escluse
mkdir -p "$NVME_MNT"/{proc,sys,dev,run,tmp,mnt}
chmod 1777 "$NVME_MNT/tmp"

echo "Generando /etc/fstab..."
cat <<EOF > "$NVME_MNT/etc/fstab"
# /etc/fstab: static file system information.
#
# <file system>      <mount point>  <type>  <options>  <dump>  <pass>
LABEL=$NEW_LABEL     /              ext4    defaults   0       1
$EFI_IDENTIFIER      /boot/efi      vfat    defaults   0       1
EOF

echo "Desmontando unidades..."
umount "$NVME_MNT"
rmdir "$NVME_MNT" 2>/dev/null || true

echo ""
echo "=========================================================="
echo "¡Instalación completada con éxito!"
echo "=========================================================="
echo "PASO FINAL OBLIGATORIO:"
echo "Modifica tu archivo /boot/efi/cmdline.txt"
echo "Busca la opción: root=LABEL=${SRC_LABEL:-PS5_ROOT}"
echo "Y cámbiala por:  root=LABEL=$NEW_LABEL"
echo "=========================================================="
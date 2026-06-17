# PS5 Linux M.2 Installer Script 🐧🎮

Este script automatiza por completo la instalación y migración de tu sistema Linux Live (ej. Ubuntu) desde un almacenamiento USB externo directamente al **SSD M.2 NVMe interno** de tu PlayStation 5.

A diferencia de las versiones originales, este script incluye correcciones automáticas para evitar fallos comunes de particionado y dependencias faltantes.

## ✨ Características y Mejoras
* **Instalación de Dependencias:** Detecta si `rsync` está instalado y lo configura automáticamente si falta.
* **Particionado Automático:** Si el SSD M.2 no tiene particiones creadas (`nvme0n1p1`), el script genera automáticamente una tabla GPT y la partición necesaria sin interrumpir el proceso.
* **Formateo Seguro:** Prepara la partición en formato `ext4` asignando las etiquetas (*labels*) correctas de forma automática.
* **Traducción al Español:** Mensajes en consola limpios y claros para seguir el progreso en tiempo real.

---

## 🚀 Requisitos Previos
1. Tener una PS5 ejecutando Linux desde un entorno Live (USB/SSD externo).
2. Tener un SSD M.2 NVMe compatible instalado en la consola.
3. Conexión a internet en la PS5 (necesaria únicamente si el sistema requiere descargar `rsync`).

---

## 🛠️ Modo de Uso

Sigue estos sencillos pasos desde la terminal de tu PS5:

### 1. Clonar o descargar el repositorio
Si no tienes el script en tu sistema, descárgalo o clónalo:
```bash
git clone [https://github.com/TU_USUARIO/TU_REPOSITORIO.git](https://github.com/TU_USUARIO/TU_REPOSITORIO.git)
cd TU_REPOSITORIO
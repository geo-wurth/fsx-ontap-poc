#!/bin/bash
# Script de teste de performance simples utilizando fio

echo "=== Teste de Performance (FIO) ==="

if ! command -v fio &> /dev/null; then
    echo "Instalando fio..."
    sudo yum install -y fio
fi

read -p "O volume NFS está montado em qual diretório? (ex: /mnt/fsx-nfs): " MOUNT_DIR

if ! grep -qs "$MOUNT_DIR" /proc/mounts; then
    echo "[ERRO] Diretório $MOUNT_DIR não parece estar montado."
    exit 1
fi

echo "Iniciando teste de sequential write de 1GB..."
sudo fio --name=seqwrite --ioengine=libaio --iodepth=32 --rw=write --bs=1M --direct=1 --size=1G --numjobs=1 --directory=$MOUNT_DIR --group_reporting

echo "Iniciando teste de sequential read de 1GB..."
sudo fio --name=seqread --ioengine=libaio --iodepth=32 --rw=read --bs=1M --direct=1 --size=1G --numjobs=1 --directory=$MOUNT_DIR --group_reporting

echo "Limpando arquivos gerados pelo fio..."
sudo rm -f $MOUNT_DIR/seqwrite*
sudo rm -f $MOUNT_DIR/seqread*

echo "=== Fim do Teste ==="

#!/bin/bash
# Script para testar a montagem e leitura/escrita no NFS a partir da EC2 Linux

set -e

echo "=== Teste NFS ==="

if ! command -v mount.nfs &> /dev/null; then
    echo "Instalando nfs-utils..."
    sudo yum install -y nfs-utils
fi

read -p "Informe o DNS NFS Endpoint da SVM: " SVM_NFS

MOUNT_DIR="/mnt/fsx-nfs"
VOL_PATH="/vol_nfs"

echo "Criando diretório de montagem em $MOUNT_DIR..."
sudo mkdir -p $MOUNT_DIR

echo "Montando volume NFS ($SVM_NFS:$VOL_PATH)..."
sudo mount -t nfs $SVM_NFS:$VOL_PATH $MOUNT_DIR

if grep -qs "$MOUNT_DIR" /proc/mounts; then
    echo "[OK] Volume NFS montado com sucesso."
else
    echo "[ERRO] Falha ao montar o volume NFS."
    exit 1
fi

echo "Testando permissão de escrita..."
TEST_FILE="$MOUNT_DIR/teste_nfs.txt"

if sudo sh -c "echo 'Arquivo de teste criado pelo Linux no volume NFS' > $TEST_FILE"; then
    echo "[OK] Arquivo criado com sucesso."
else
    echo "[ERRO] Não foi possível criar o arquivo. Verifique as permissões de export policy no ONTAP."
fi

echo "Lendo arquivo:"
cat $TEST_FILE

echo "Removendo arquivo..."
sudo rm -f $TEST_FILE

echo "Desmontando volume NFS..."
sudo umount $MOUNT_DIR
echo "[OK] Volume desmontado."

echo "=== Teste finalizado com sucesso! ==="

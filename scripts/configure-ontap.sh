#!/bin/bash
# Script de configuração operacional do FSx for ONTAP para a POC
# Execute este script a partir da EC2 Linux via SSM.

set -e

echo "=== Configuração FSx for ONTAP ==="

read -p "Informe o DNS Management Endpoint (ex: management.fs-xxxx.fsx.us-east-1.amazonaws.com ou da SVM): " SVM_ENDPOINT
read -p "Informe a rede CIDR dos clientes para liberar o NFS (ex: 10.0.1.0/24 ou 0.0.0.0/0): " CLIENT_CIDR
read -s -p "Informe a senha do admin (padrão: Fsx@dm1n): " ADMIN_PASS
ADMIN_PASS=${ADMIN_PASS:-Fsx@dm1n}
echo ""
read -p "Informe o nome de usuário local SMB (padrão: smbuser): " SMB_USER
SMB_USER=${SMB_USER:-smbuser}
read -s -p "Informe a senha para o novo usuário SMB (padrão: Fsx@dm1n): " SMB_PASS
SMB_PASS=${SMB_PASS:-Fsx@dm1n}
echo ""

echo "[1/4] Configurando NFS Export Policy para permitir a rede dos clientes..."
sshpass -p "$ADMIN_PASS" ssh -o StrictHostKeyChecking=no vsadmin@$SVM_ENDPOINT "vserver export-policy rule create -vserver svmpoc -policyname default -ruleindex 1 -protocol nfs -clientmatch $CLIENT_CIDR -rorule any -rwrule any -superuser any" || true

echo "[2/4] Configurando Servidor SMB em Workgroup (FSXSMB)..."
sshpass -p "$ADMIN_PASS" ssh -o StrictHostKeyChecking=no vsadmin@$SVM_ENDPOINT "vserver cifs create -vserver svmpoc -cifs-server FSXSMB -workgroup WORKGROUP" || true

echo "[3/4] Criando usuário local SMB ($SMB_USER)..."
sshpass -p "$ADMIN_PASS" ssh -o StrictHostKeyChecking=no vsadmin@$SVM_ENDPOINT "vserver cifs users-and-groups local-user create -vserver svmpoc -user-name $SMB_USER -description \"Local SMB User for POC\"" || true

sshpass -p "$ADMIN_PASS" ssh -o StrictHostKeyChecking=no vsadmin@$SVM_ENDPOINT <<EOF
vserver cifs users-and-groups local-user set-password -vserver svmpoc -user-name $SMB_USER
$SMB_PASS
$SMB_PASS
EOF

echo "[4/4] Criando Shares SMB para vol_smb e vol_nfs..."
sshpass -p "$ADMIN_PASS" ssh -o StrictHostKeyChecking=no vsadmin@$SVM_ENDPOINT "vserver cifs share create -vserver svmpoc -share-name vol_smb -path /vol_smb" || true
sshpass -p "$ADMIN_PASS" ssh -o StrictHostKeyChecking=no vsadmin@$SVM_ENDPOINT "vserver cifs share create -vserver svmpoc -share-name vol_nfs -path /vol_nfs" || true

echo "=== Concluído! ==="
echo "Valide as configurações conectando via SSH: ssh fsxadmin@$SVM_ENDPOINT"

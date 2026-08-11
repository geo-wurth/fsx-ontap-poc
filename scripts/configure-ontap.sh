#!/bin/bash
# Script de configuração operacional do FSx for ONTAP para a POC
# Execute este script a partir da EC2 Linux via SSM.

set -e

echo "=== Configuração FSx for ONTAP ==="

read -p "Informe o DNS Management Endpoint da SVM (svm_management_dns_name no output): " SVM_ENDPOINT
read -p "Informe a rede CIDR dos clientes para liberar o NFS (ex: 10.0.1.0/24): " CLIENT_CIDR
read -p "Informe o IP Privado da instância Windows (windows_private_ip no output): " WIN_IP
read -s -p "Informe a senha do fsxadmin/vsadmin: " ADMIN_PASS
echo ""
read -p "Informe o nome de usuário local SMB que deseja criar (ex: smbuser): " SMB_USER
read -s -p "Informe a senha para o novo usuário SMB (deve ser complexa): " SMB_PASS
echo ""

echo "[1/4] Configurando NFS Export Policy para permitir a rede dos clientes..."
sshpass -p "$ADMIN_PASS" ssh -o StrictHostKeyChecking=no vsadmin@$SVM_ENDPOINT "vserver export-policy rule create -vserver svmpoc -policyname default -ruleindex 1 -protocol nfs -clientmatch $CLIENT_CIDR -rorule any -rwrule any -superuser any"

echo "[2/4] Configurando Servidor SMB em Workgroup..."
sshpass -p "$ADMIN_PASS" ssh -o StrictHostKeyChecking=no vsadmin@$SVM_ENDPOINT "vserver cifs create -vserver svmpoc -cifs-server SMB-POC -workgroup WORKGROUP"

echo "[3/4] Criando usuário local SMB ($SMB_USER)..."
sshpass -p "$ADMIN_PASS" ssh -o StrictHostKeyChecking=no vsadmin@$SVM_ENDPOINT "vserver cifs users-and-groups local-user create -vserver svmpoc -user-name $SMB_USER -description \"Local SMB User for POC\""

# A API SSH do ONTAP para definir senha de usuário local via CLI pode exigir interação se não usar batch, mas tentaremos com o password injetado.
# Como workaround, o ONTAP suporta set-password em batch mode a partir de versões mais recentes, ou usar a api REST.
# Para manter a simplicidade em bash com sshpass, vamos forçar a troca de senha.
# O ONTAP pede a senha do admin e depois as senhas novas. Usaremos um workaround simples:
echo "Por favor, para definir a senha do $SMB_USER o ONTAP exige um prompt interativo."
echo "Execute o comando abaixo e digite a senha '$SMB_PASS' quando solicitado:"
echo "ssh vsadmin@$SVM_ENDPOINT \"vserver cifs users-and-groups local-user set-password -vserver svmpoc -user-name $SMB_USER\""
echo "OBS: Pressione ENTER para tentar executar de forma automatizada (pode falhar dependendo da versão do ONTAP)."
read -p ""

sshpass -p "$ADMIN_PASS" ssh -o StrictHostKeyChecking=no vsadmin@$SVM_ENDPOINT <<EOF
vserver cifs users-and-groups local-user set-password -vserver svmpoc -user-name $SMB_USER
$SMB_PASS
$SMB_PASS
EOF

echo "[4/4] Criando Share SMB..."
sshpass -p "$ADMIN_PASS" ssh -o StrictHostKeyChecking=no vsadmin@$SVM_ENDPOINT "vserver cifs share create -vserver svmpoc -share-name pocshare -path /vol_smb -share-properties oplocks,browsable,changenotify"

echo "=== Concluído! ==="
echo "Valide se a criação foi bem sucedida acessando o ambiente ONTAP: ssh vsadmin@$SVM_ENDPOINT"

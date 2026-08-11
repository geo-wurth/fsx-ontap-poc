#!/bin/bash
# Script de teste de conectividade do Linux para o FSx

echo "=== Teste de Conectividade ==="

read -p "Informe o DNS Management Endpoint da SVM: " SVM_MGMT
read -p "Informe o DNS NFS Endpoint da SVM: " SVM_NFS

echo "Testando conectividade de gerência (TCP 22) para $SVM_MGMT..."
if nc -zv -w 5 $SVM_MGMT 22; then
  echo "[OK] Conexão TCP 22 na gerência bem sucedida!"
else
  echo "[FALHA] Não foi possível conectar na porta 22 (SSH)."
fi

echo "Testando conectividade NFS (TCP 2049) para $SVM_NFS..."
if nc -zv -w 5 $SVM_NFS 2049; then
  echo "[OK] Conexão TCP 2049 (NFS) bem sucedida!"
else
  echo "[FALHA] Não foi possível conectar na porta 2049 (NFS)."
fi

echo "Visualizando shares NFS disponíveis via showmount..."
showmount -e $SVM_NFS || echo "Não foi possível listar via showmount (pode estar bloqueado)."

echo "=== Fim do teste ==="

#!/bin/bash

set -e

echo "🚀 Iniciando deploy automatizado do WordPress..."

# Configurações
TERRAFORM_DIR="terraform"
ANSIBLE_DIR="ansible"

# Entrar no diretório do Terraform
cd "$TERRAFORM_DIR"

echo "📦 Inicializando Terraform..."
terraform init

echo "🔄 Aplicando configuração do Terraform..."
terraform apply -auto-approve

# Obter o IP público da instância
PUBLIC_IP=$(terraform output -raw instance_public_ip)
INSTANCE_URL=$(terraform output -raw instance_url)

# 🔑 CORRIGIDO: Caminho absoluto para a chave
SSH_KEY_PATH="$(pwd)/wordpress-key.pem"
KEY_CREATED=$(terraform output -raw key_created)

echo "📡 IP Público da instância: $PUBLIC_IP"
echo "🔑 Chave SSH: $SSH_KEY_PATH"
echo "🔑 Nova chave criada: $KEY_CREATED"

# Verificar se a chave existe
if [ ! -f "$SSH_KEY_PATH" ]; then
    echo "❌ ERRO: Chave SSH não encontrada em: $SSH_KEY_PATH"
    exit 1
fi

# Voltar ao diretório raiz
cd ..

# Configurar inventory do Ansible
echo "📝 Configurando inventory do Ansible..."
cat > "$ANSIBLE_DIR/inventory.ini" << EOF
[wordpress]
$PUBLIC_IP

[wordpress:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=$SSH_KEY_PATH
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ConnectTimeout=30'
EOF

# Aguardar a instância ficar totalmente inicializada
echo "⏳ Aguardando instância ficar totalmente disponível (60 segundos)..."
sleep 60

# Tentar conexão SSH com retry melhorado
MAX_RETRIES=15
RETRY_COUNT=0

echo "🔍 Aguardando user_data completar..."
until ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=30 ubuntu@$PUBLIC_IP "test -f /tmp/user_data_completed" || [ $RETRY_COUNT -eq $MAX_RETRIES ]
do
    echo "🔄 Tentativa $((RETRY_COUNT+1))/$MAX_RETRIES - Aguardando user_data completar..."
    sleep 30
    RETRY_COUNT=$((RETRY_COUNT+1))
done

if [ $RETRY_COUNT -eq $MAX_RETRIES ]; then
    echo "❌ Falha ao conectar na instância via SSH após $MAX_RETRIES tentativas"
    echo "💡 Verificando status da instância..."
    cd "$TERRAFORM_DIR"
    terraform show
    exit 1
fi

echo "✅ User_data completado, executando Ansible..."

# Executar Ansible
cd "$ANSIBLE_DIR"

# Primeiro teste de conexão
echo "🔍 Testando conexão Ansible..."
ansible -i inventory.ini wordpress -m ping

# Executar playbook
echo "🎯 Executando Ansible playbook..."
ansible-playbook -i inventory.ini playbook.yml

echo ""
echo "🎉 ✅ DEPLOY CONCLUÍDO COM SUCESSO!"
echo "🌐 WordPress está disponível em: $INSTANCE_URL"
echo ""
echo "🔑 Informações de acesso:"
echo "   SSH: ssh -i $SSH_KEY_PATH ubuntu@$PUBLIC_IP"
echo ""
echo "📖 Próximos passos:"
echo "   1. Acesse: $INSTANCE_URL no seu navegador"
echo "   2. Siga o setup do WordPress"
echo "   3. Idioma: Português do Brasil"
echo "   4. Database: Use as credenciais padrão (já configuradas)"
echo ""
echo "⚙️  Comandos úteis:"
echo "   📊 Ver containers: ssh -i $SSH_KEY_PATH ubuntu@$PUBLIC_IP 'sudo docker ps'"
echo "   📋 Ver logs: ssh -i $SSH_KEY_PATH ubuntu@$PUBLIC_IP 'sudo docker logs wordpress'"
echo "   🗑️  Destruir tudo: cd terraform && terraform destroy -auto-approve"
echo ""
echo "⏰ Observação: Pode levar 1-2 minutos para o WordPress inicializar completamente após o deploy."
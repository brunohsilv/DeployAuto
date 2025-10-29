#!/bin/bash

set -e

echo "🔍 Verificando pré-requisitos para deploy do WordPress..."
echo ""

# Função para verificar comando
check_command() {
    local cmd=$1
    local install_url=$2
    
    if command -v $cmd &> /dev/null; then
        echo "✅ $cmd: $(which $cmd)"
        return 0
    else
        echo "❌ $cmd: NÃO ENCONTRADO"
        echo "   💡 Instale em: $install_url"
        return 1
    fi
}

# Verificar Terraform
echo "1. Verificando Terraform..."
check_command "terraform" "https://developer.hashicorp.com/terraform/tutorials/aws-get-started/install-cli" || exit 1

# Verificar Ansible
echo ""
echo "2. Verificando Ansible..."
check_command "ansible" "https://docs.ansible.com/ansible/latest/installation_guide/intro_installation.html" || exit 1

# Verificar AWS CLI
echo ""
echo "3. Verificando AWS CLI..."
check_command "aws" "https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html" || exit 1

# Verificar autenticação AWS
echo ""
echo "4. Verificando autenticação AWS..."
if aws sts get-caller-identity &> /dev/null; then
    AWS_ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
    AWS_USER=$(aws sts get-caller-identity --query Arn --output text | cut -d'/' -f2)
    echo "✅ AWS autenticado:"
    echo "   👤 Usuário: $AWS_USER"
    echo "   📦 Conta: $AWS_ACCOUNT"
else
    echo "❌ AWS não autenticado"
    echo "   💡 Execute: aws configure"
    echo "   💡 Ou defina variáveis: AWS_ACCESS_KEY_ID e AWS_SECRET_ACCESS_KEY"
    exit 1
fi

# Verificar região configurada
echo ""
echo "5. Verificando região AWS..."
AWS_REGION=$(aws configure get region || echo "us-east-1")
echo "📍 Região: $AWS_REGION"

# Verificar permissões básicas
echo ""
echo "6. Verificando permissões AWS..."
if aws ec2 describe-instances --max-items 1 &> /dev/null; then
    echo "✅ Permissões EC2: OK"
else
    echo "⚠️  Possível problema com permissões EC2"
    echo "   💡 Verifique se o usuário tem permissões para: EC2, VPC, EIP"
fi

echo ""
echo "🎉 Todos os pré-requisitos verificados!"
echo "🚀 Execute ./deploy.sh para iniciar o deploy"
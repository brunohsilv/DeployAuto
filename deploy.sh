#!/bin/bash

set -e

echo "🚀 Iniciando deploy automatizado do WordPress..."

# Configurações
TERRAFORM_DIR="terraform"
ANSIBLE_DIR="ansible"

# ==============================
# CRIAR PASTAS DE LOG E BENCHMARK
# ==============================
LOG_DIR="logs"
BENCH_DIR="benchmarks"
mkdir -p "$LOG_DIR"
mkdir -p "$BENCH_DIR"

NEXT_LOG_NUM=$(printf "%03d" $(($(ls -1 "$LOG_DIR"/*.log 2>/dev/null | wc -l) + 1)))
LOG_FILE="$LOG_DIR/log_${NEXT_LOG_NUM}.log"

NEXT_BENCH_NUM=$(printf "%03d" $(($(ls -1 "$BENCH_DIR"/*.csv 2>/dev/null | wc -l) + 1)))
BENCH_FILE="$BENCH_DIR/benchmark_${NEXT_BENCH_NUM}.csv"
CONSOLIDATED="$BENCH_DIR/all_benchmarks.csv"

PIPELINE_START_TS=$(date +"%Y-%m-%dT%H:%M:%S%z")
PIPELINE_START_EPOCH=$(date +%s)

# ==============================
# ETAPA TERRAFORM
# ==============================
TF_START_TS=$(date +"%Y-%m-%dT%H:%M:%S%z")
TF_START_EPOCH=$(date +%s)

# Entrar no diretório do Terraform
cd "$TERRAFORM_DIR"

echo "📦 Inicializando Terraform..."
terraform init

echo "🔄 Aplicando configuração do Terraform..."
terraform apply -auto-approve

# Obter o IP público da instância
PUBLIC_IP=$(terraform output -raw instance_public_ip)
INSTANCE_URL=$(terraform output -raw instance_url)

# 🔑 Caminho absoluto para a chave
SSH_KEY_PATH="$(pwd)/wordpress-key.pem"
KEY_CREATED=$(terraform output -raw key_created)

TF_END_TS=$(date +"%Y-%m-%dT%H:%M:%S%z")
TF_END_EPOCH=$(date +%s)
TF_DURATION=$((TF_END_EPOCH - TF_START_EPOCH))

cd ..

# ==============================
# CONFIGURAR INVENTORY DO ANSIBLE
# ==============================
echo "📝 Configurando inventory do Ansible..."
cat > "$ANSIBLE_DIR/inventory.ini" << EOF
[wordpress]
$PUBLIC_IP

[wordpress:vars]
ansible_user=ubuntu
ansible_ssh_private_key_file=$SSH_KEY_PATH
ansible_ssh_common_args='-o StrictHostKeyChecking=no -o ConnectTimeout=30'
EOF

# ==============================
# ESPERA INSTÂNCIA
# ==============================
echo "⏳ Aguardando instância ficar totalmente disponível (60 segundos)..."
sleep 60

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

# ==============================
# ETAPA ANSIBLE
# ==============================
ANS_START_TS=$(date +"%Y-%m-%dT%H:%M:%S%z")
ANS_START_EPOCH=$(date +%s)

cd "$ANSIBLE_DIR"

echo "🔍 Testando conexão Ansible..."
ansible -i inventory.ini wordpress -m ping

echo "🎯 Executando Ansible playbook..."
ansible-playbook -i inventory.ini playbook.yml

ANS_END_TS=$(date +"%Y-%m-%dT%H:%M:%S%z")
ANS_END_EPOCH=$(date +%s)
ANS_DURATION=$((ANS_END_EPOCH - ANS_START_EPOCH))

cd ..

PIPELINE_END_TS=$(date +"%Y-%m-%dT%H:%M:%S%z")
PIPELINE_END_EPOCH=$(date +%s)
TOTAL_DURATION=$((PIPELINE_END_EPOCH - PIPELINE_START_EPOCH))

# ==============================
# GERAR LOG
# ==============================
cat > "$LOG_FILE" << EOF
DEPLOYMENT BENCHMARK LOG
Project: WordPress IaC Automation
Author: Bruno
Generated_at: $PIPELINE_START_TS
==============================================

[PIPELINE_START]
timestamp: $PIPELINE_START_TS
epoch: $PIPELINE_START_EPOCH

[STAGE_TERRAFORM]
start: $TF_START_TS
end:   $TF_END_TS
duration_seconds: $TF_DURATION
instance_public_ip: $PUBLIC_IP

[STAGE_ANSIBLE]
start: $ANS_START_TS
end:   $ANS_END_TS
duration_seconds: $ANS_DURATION

[PIPELINE_END]
timestamp: $PIPELINE_END_TS
total_duration_seconds: $TOTAL_DURATION

==============================================
END OF LOG
==============================================
EOF

# ==============================
# GERAR CSV INDIVIDUAL E CONSOLIDADO
# ==============================
echo "run_id,terraform_seconds,ansible_seconds,total_seconds,public_ip,timestamp" > "$BENCH_FILE"
echo "$NEXT_BENCH_NUM,$TF_DURATION,$ANS_DURATION,$TOTAL_DURATION,$PUBLIC_IP,$PIPELINE_START_TS" >> "$BENCH_FILE"

if [ ! -f "$CONSOLIDATED" ]; then
    echo "run_id,terraform_seconds,ansible_seconds,total_seconds,public_ip,timestamp" > "$CONSOLIDATED"
fi
echo "$NEXT_BENCH_NUM,$TF_DURATION,$ANS_DURATION,$TOTAL_DURATION,$PUBLIC_IP,$PIPELINE_START_TS" >> "$CONSOLIDATED"

# ==============================
# MENSAGEM FINAL
# ==============================
echo ""
echo "🎉 ✅ DEPLOY CONCLUÍDO COM SUCESSO!"
echo "🌐 WordPress está disponível em: $INSTANCE_URL"
echo ""
echo "📝 Log gerado: $LOG_FILE"
echo "📊 Benchmark individual: $BENCH_FILE"
echo "📈 Dataset consolidado: $CONSOLIDATED"
echo ""

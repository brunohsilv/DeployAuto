#!/bin/bash

set -e

echo "🚀 Iniciando deploy automatizado do WordPress..."

# ==============================
# MARCAR INÍCIO DO PIPELINE
# ==============================
PIPELINE_START_TS=$(date +"%Y-%m-%dT%H:%M:%S%z")
PIPELINE_START_EPOCH=$(date +%s)

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

# Contar apenas arquivos de benchmark individuais (ignora all_benchmarks.csv)
NEXT_BENCH_NUM=$(printf "%03d" $(($(ls -1 "$BENCH_DIR"/benchmark_*.csv 2>/dev/null | wc -l) + 1)))
BENCH_FILE="$BENCH_DIR/benchmark_${NEXT_BENCH_NUM}.csv"
CONSOLIDATED="$BENCH_DIR/all_benchmarks.csv"

# ==============================
# ETAPA TERRAFORM
# ==============================
cd "$TERRAFORM_DIR"

echo "📦 Inicializando Terraform..."
terraform init

echo "🔄 Aplicando configuração do Terraform..."
terraform apply -auto-approve

# Obter o IP público da instância
PUBLIC_IP=$(terraform output -raw instance_public_ip)
INSTANCE_URL=$(terraform output -raw instance_url)

# Caminho absoluto para a chave
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
# ESPERA DINÂMICA DA INSTÂNCIA
# ==============================
MAX_RETRIES=20
SLEEP_INTERVAL=15
RETRY_COUNT=0

echo "🔍 Aguardando instância ficar disponível e user_data completar..."

while true; do
    if ssh -i "$SSH_KEY_PATH" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$PUBLIC_IP "test -f /tmp/user_data_completed" 2>/dev/null; then
        echo "✅ Instância pronta e user_data completado!"
        break
    fi

    RETRY_COUNT=$((RETRY_COUNT+1))
    if [ $RETRY_COUNT -ge $MAX_RETRIES ]; then
        echo "❌ Timeout: não foi possível conectar na instância após $MAX_RETRIES tentativas"
        cd "$TERRAFORM_DIR"
        terraform show
        exit 1
    fi

    echo "⏳ Tentativa $RETRY_COUNT/$MAX_RETRIES: Instância ainda não pronta, aguardando $SLEEP_INTERVAL segundos..."
    sleep $SLEEP_INTERVAL
done

# ==============================
# ETAPA ANSIBLE
# ==============================
cd "$ANSIBLE_DIR"

echo "🔍 Testando conexão Ansible..."
ansible -i inventory.ini wordpress -m ping

echo "🎯 Executando Ansible playbook..."
ansible-playbook -i inventory.ini playbook.yml

cd ..

# ==============================
# MARCAR FIM DO PIPELINE
# ==============================
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

[PIPELINE]
start: $PIPELINE_START_TS
end:   $PIPELINE_END_TS
duration_seconds: $TOTAL_DURATION
instance_public_ip: $PUBLIC_IP

==============================================
END OF LOG
==============================================
EOF

# ==============================
# GERAR CSV INDIVIDUAL E CONSOLIDADO
# ==============================
echo "run_id,total_seconds,public_ip,timestamp" > "$BENCH_FILE"
echo "$NEXT_BENCH_NUM,$TOTAL_DURATION,$PUBLIC_IP,$PIPELINE_START_TS" >> "$BENCH_FILE"

if [ ! -f "$CONSOLIDATED" ]; then
    echo "run_id,total_seconds,public_ip,timestamp" > "$CONSOLIDATED"
fi
echo "$NEXT_BENCH_NUM,$TOTAL_DURATION,$PUBLIC_IP,$PIPELINE_START_TS" >> "$CONSOLIDATED"

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

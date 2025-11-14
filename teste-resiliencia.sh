#!/bin/bash

set -e

echo "🎯 TESTE DE RESILIÊNCIA - CENÁRIO REAL"
echo "📅 $(date)"
echo ""

# Configurações
TERRAFORM_DIR="terraform"
SSH_KEY="$TERRAFORM_DIR/wordpress-key.pem"
LOG_FILE="resultado_resiliencia.log"

# Limpar arquivo de log anterior
> "$LOG_FILE"

# Função para log
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Função para verificar conectividade
check_ssh_connection() {
    if ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$PUBLIC_IP true; then
        log "❌ ERRO: Não foi possível conectar via SSH na instância"
        exit 1
    fi
}

# Obter IP
cd "$TERRAFORM_DIR"
PUBLIC_IP=$(terraform output -raw instance_public_ip)
cd ..

log "📍 Instância: $PUBLIC_IP"
log "🎯 Objetivo: PHP 8.3 → 8.0 (downgrade forçado por incompatibilidade)"
log ""

# Verificar conectividade antes de iniciar
log "🔍 Verificando conectividade com a instância..."
check_ssh_connection
log "   ✅ Conectividade SSH OK"

# Iniciar cronômetro geral
START_TIME=$(date +%s)

# 1. Verificar versões atuais
log "1. 📊 VERSÕES ATUAIS:"
CURRENT_IMAGE=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "sudo docker inspect wordpress --format='{{.Config.Image}}' 2>/dev/null" || echo "Não disponível")
log "   🐳 Imagem: $CURRENT_IMAGE"

PHP_VERSION=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "sudo docker exec wordpress php --version 2>/dev/null | head -1 | cut -d' ' -f2" || echo "Não detectado")
log "   🐘 PHP: $PHP_VERSION"

# 2. Teste antes da mudança
log ""
log "2. 🧪 TESTE ANTES DA MUDANÇA:"

# Teste de saúde completo
BEFORE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://$PUBLIC_IP || echo "000")
log "   🌐 Status HTTP: $BEFORE_STATUS"

BEFORE_RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" --max-time 10 http://$PUBLIC_IP || echo "0")
log "   ⏱️  Tempo de resposta: ${BEFORE_RESPONSE_TIME}s"

# Verificar conteúdo (com timeout)
BEFORE_TITLE=$(curl -s --max-time 10 http://$PUBLIC_IP | grep -o "<title>.*</title>" | head -1 || echo "Título não encontrado")
log "   📄 Conteúdo: $BEFORE_TITLE"

# 3. INICIAR MUDANÇA - Downgrade forçado
log ""
log "3. 🔄 INICIANDO DOWNGRADE: PHP 8.3 → 8.0..."

# Iniciar medição de downtime
DOWNTIME_START=$(date +%s)
OPERATION_START=$(date +%s)

# Parar container (com verificação de erro)
log "   ⏹️  Parando container..."
if ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "cd /home/ubuntu/wordpress && sudo docker compose stop wordpress 2>/dev/null"; then
    log "   ⚠️  Container já parado ou não encontrado, continuando..."
fi

# Baixar nova imagem
log "   📥 Baixando wordpress:php8.0-apache..."
if ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "sudo docker pull wordpress:php8.0-apache"; then
    log "❌ ERRO: Falha ao baixar a imagem Docker"
    exit 1
fi

# Atualizar configuração
log "   ⚙️  Atualizando docker-compose.yml..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "cd /home/ubuntu/wordpress && sed -i 's|image: wordpress:latest|image: wordpress:php8.0-apache|' docker-compose.yml"

# Iniciar novo container
log "   🚀 Iniciando novo container..."
if ! ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "cd /home/ubuntu/wordpress && sudo docker compose up -d wordpress"; then
    log "❌ ERRO: Falha ao iniciar container"
    exit 1
fi

OPERATION_END=$(date +%s)
OPERATION_DURATION=$((OPERATION_END - OPERATION_START))

# 4. AGUARDAR E MEDIR DOWNTIME REAL
log ""
log "4. ⏳ AGUARDANDO ESTABILIZAÇÃO E MEDINDO DOWNTIME..."

ATTEMPTS=0
MAX_ATTEMPTS=30
DOWNTIME_END=0
SERVICE_RESTORED=false

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://$PUBLIC_IP || echo "000")
    
    if [ "$STATUS" = "200" ] || [ "$STATUS" = "302" ]; then
        DOWNTIME_END=$(date +%s)
        SERVICE_RESTORED=true
        log "   ✅ Serviço restaurado na tentativa $((ATTEMPTS + 1))"
        break
    fi
    
    ATTEMPTS=$((ATTEMPTS + 1))
    sleep 2
done

if [ "$SERVICE_RESTORED" = false ]; then
    DOWNTIME_END=$(date +%s)
    log "   ⚠️  Serviço não restaurado completamente após $MAX_ATTEMPTS tentativas"
fi

DOWNTIME_DURATION=$((DOWNTIME_END - DOWNTIME_START))

# Aguardar mais um pouco para total estabilização
log "   ⏳ Aguardando estabilização final..."
sleep 10

# 5. VERIFICAÇÃO COMPLETA APÓS MUDANÇA
log ""
log "5. ✅ VERIFICAÇÃO APÓS MUDANÇA:"

# Verificar versões
NEW_IMAGE=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "sudo docker inspect wordpress --format='{{.Config.Image}}' 2>/dev/null" || echo "Não disponível")
log "   🐳 Nova imagem: $NEW_IMAGE"

NEW_PHP_VERSION=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "sudo docker exec wordpress php --version 2>/dev/null | head -1 | cut -d' ' -f2" || echo "Não detectado")
log "   🐘 Novo PHP: $NEW_PHP_VERSION"

# Teste de saúde completo após
AFTER_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://$PUBLIC_IP || echo "000")
log "   🌐 Status HTTP: $AFTER_STATUS"

AFTER_RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" --max-time 10 http://$PUBLIC_IP || echo "0")
log "   ⏱️  Tempo de resposta: ${AFTER_RESPONSE_TIME}s"

# Verificar conteúdo após
AFTER_TITLE=$(curl -s --max-time 10 http://$PUBLIC_IP | grep -o "<title>.*</title>" | head -1 || echo "Título não encontrado")
log "   📄 Conteúdo: $AFTER_TITLE"

# Testar admin WordPress
ADMIN_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://$PUBLIC_IP/wp-admin/ || echo "000")
log "   ⚙️  Status do admin: $ADMIN_STATUS"

# Finalizar medições
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

# 6. RELATÓRIO FINAL
log ""
log "=========================================="
log "📊 RELATÓRIO FINAL - RESILIÊNCIA"
log "=========================================="
log "🕒 TEMPO TOTAL: $TOTAL_DURATION segundos"
log "⚡ DOWNTIME REAL: $DOWNTIME_DURATION segundos"
log "🔧 OPERAÇÃO (comandos): $OPERATION_DURATION segundos"
log ""
log "📦 ESTADO INICIAL:"
log "   • Imagem: $CURRENT_IMAGE"
log "   • PHP: $PHP_VERSION"
log "   • Status: HTTP $BEFORE_STATUS"
log "   • Performance: ${BEFORE_RESPONSE_TIME}s"
log ""
log "📦 ESTADO FINAL:"
log "   • Imagem: $NEW_IMAGE"
log "   • PHP: $NEW_PHP_VERSION"
log "   • Status: HTTP $AFTER_STATUS"
log "   • Performance: ${AFTER_RESPONSE_TIME}s"
log ""

# Análise automática
log "🔍 ANÁLISE:"
if [ "$AFTER_STATUS" = "200" ] || [ "$AFTER_STATUS" = "302" ]; then
    log "   ✅ SUCESSO OPERACIONAL"
    log "   💡 Sistema manteve funcionalidade após mudança radical"
else
    log "   ⚠️  PROBLEMAS DETECTADOS"
    log "   💡 Sistema pode ter issues de compatibilidade"
fi

if [ $DOWNTIME_DURATION -le 30 ]; then
    log "   ✅ DOWNTIME ACEITÁVEL"
    log "   💡 Interrupção mínima do serviço"
else
    log "   ⚠️  DOWNTIME ELEVADO"
    log "   💡 Possível impacto nos usuários"
fi

log ""
log "🎯 PRÓXIMOS PASSOS:"
log "   • Estado atual: PHP 8.0 (para demonstração)"
log "   • Rollback manual disponível se necessário"
log "   • Dados salvos em: $LOG_FILE"
log "   • Use estes dados para comparar com deploy manual"

log ""
log "📋 RESUMO PARA APRESENTAÇÃO:"
log "   • Mudança: PHP 8.3 → 8.0"
log "   • Tempo total: $TOTAL_DURATION segundos"
log "   • Downtime: $DOWNTIME_DURATION segundos"
log "   • Resultado: $( [ "$AFTER_STATUS" = "200" ] || [ "$AFTER_STATUS" = "302" ] && echo "SUCESSO" || echo "FALHA PARCIAL" )"

echo ""
echo "🎉 Teste de resiliência concluído!"
echo "📄 Relatório detalhado salvo em: $LOG_FILE"
echo ""
echo "💡 Executar o deploy manual e comparar os resultados"
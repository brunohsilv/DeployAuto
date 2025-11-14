#!/bin/bash

set -e

echo "🔄 ROLLBACK PARA VERSÃO ORIGINAL"
echo "📅 $(date)"
echo ""

# Configurações
TERRAFORM_DIR="terraform"
SSH_KEY="$TERRAFORM_DIR/wordpress-key.pem"
LOG_FILE="rollback.log"

# Função para log
log() {
    echo "$1" | tee -a "$LOG_FILE"
}

# Obter IP
cd "$TERRAFORM_DIR"
PUBLIC_IP=$(terraform output -raw instance_public_ip)
cd ..

log "📍 Instância: $PUBLIC_IP"
log "🎯 Objetivo: PHP 8.0 → 8.3 (rollback para versão original)"
log ""

# Iniciar cronômetro
START_TIME=$(date +%s)

# 1. Verificar estado atual
log "1. 📊 ESTADO ATUAL:"
CURRENT_IMAGE=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "sudo docker inspect wordpress --format='{{.Config.Image}}' 2>/dev/null" || echo "Não disponível")
log "   🐳 Imagem atual: $CURRENT_IMAGE"

CURRENT_PHP=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "sudo docker exec wordpress php --version 2>/dev/null | head -1 | cut -d' ' -f2" || echo "Não detectado")
log "   🐘 PHP atual: $CURRENT_PHP"

# Teste antes do rollback
BEFORE_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://$PUBLIC_IP || echo "000")
log "   🌐 Status antes: HTTP $BEFORE_STATUS"

# 2. EXECUTAR ROLLBACK
log ""
log "2. 🔄 EXECUTANDO ROLLBACK..."

# Iniciar medição de downtime
DOWNTIME_START=$(date +%s)

# Parar container atual
log "   ⏹️  Parando container atual..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "cd /home/ubuntu/wordpress && sudo docker compose stop wordpress"

# Restaurar configuração original
log "   ⚙️  Restaurando docker-compose.yml original..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "cd /home/ubuntu/wordpress && sed -i 's|image: wordpress:php8.0-apache|image: wordpress:latest|' docker-compose.yml"

# Iniciar container com versão original
log "   🚀 Iniciando container com PHP 8.3..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "cd /home/ubuntu/wordpress && sudo docker compose up -d wordpress"

# 3. AGUARDAR ESTABILIZAÇÃO
log ""
log "3. ⏳ AGUARDANDO ESTABILIZAÇÃO..."

ATTEMPTS=0
MAX_ATTEMPTS=20
ROLLBACK_SUCCESS=false

while [ $ATTEMPTS -lt $MAX_ATTEMPTS ]; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 5 http://$PUBLIC_IP || echo "000")
    
    if [ "$STATUS" = "200" ] || [ "$STATUS" = "302" ]; then
        DOWNTIME_END=$(date +%s)
        ROLLBACK_SUCCESS=true
        log "   ✅ Serviço restaurado na tentativa $((ATTEMPTS + 1))"
        break
    fi
    
    ATTEMPTS=$((ATTEMPTS + 1))
    sleep 2
done

if [ "$ROLLBACK_SUCCESS" = false ]; then
    DOWNTIME_END=$(date +%s)
    log "   ⚠️  Serviço não restaurado após $MAX_ATTEMPTS tentativas"
fi

DOWNTIME_DURATION=$((DOWNTIME_END - DOWNTIME_START))

# Aguardar estabilização final
sleep 8

# 4. VERIFICAÇÃO FINAL
log ""
log "4. ✅ VERIFICAÇÃO DO ROLLBACK:"

# Verificar versões após rollback
FINAL_IMAGE=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "sudo docker inspect wordpress --format='{{.Config.Image}}' 2>/dev/null" || echo "Não disponível")
log "   🐳 Imagem final: $FINAL_IMAGE"

FINAL_PHP=$(ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no ubuntu@$PUBLIC_IP \
    "sudo docker exec wordpress php --version 2>/dev/null | head -1 | cut -d' ' -f2" || echo "Não detectado")
log "   🐘 PHP final: $FINAL_PHP"

# Teste final de saúde
FINAL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" --max-time 10 http://$PUBLIC_IP || echo "000")
log "   🌐 Status final: HTTP $FINAL_STATUS"

FINAL_RESPONSE_TIME=$(curl -s -o /dev/null -w "%{time_total}" --max-time 10 http://$PUBLIC_IP || echo "0")
log "   ⏱️  Tempo de resposta: ${FINAL_RESPONSE_TIME}s"

# Finalizar medições
END_TIME=$(date +%s)
TOTAL_DURATION=$((END_TIME - START_TIME))

# 5. RELATÓRIO FINAL
log ""
log "=========================================="
log "📊 RELATÓRIO DE ROLLBACK"
log "=========================================="
log "🕒 Tempo total: $TOTAL_DURATION segundos"
log "⚡ Downtime: $DOWNTIME_DURATION segundos"
log ""
log "🔄 MUDANÇA REALIZADA:"
log "   • De: $CURRENT_IMAGE (PHP $CURRENT_PHP)"
log "   • Para: $FINAL_IMAGE (PHP $FINAL_PHP)"
log ""
log "📈 STATUS FINAL:"
log "   • HTTP: $FINAL_STATUS"
log "   • Performance: ${FINAL_RESPONSE_TIME}s"

# Análise do resultado
log ""
log "🔍 ANÁLISE:"
if [ "$FINAL_STATUS" = "200" ] || [ "$FINAL_STATUS" = "302" ]; then
    log "   ✅ ROLLBACK BEM-SUCEDIDO"
    log "   💡 Sistema restaurado para versão original"
else
    log "   ⚠️  ROLLBACK COM PROBLEMAS"
    log "   💡 Verificar manualmente o estado do sistema"
fi

if [ $DOWNTIME_DURATION -le 20 ]; then
    log "   ✅ DOWNTIME ACEITÁVEL"
    log "   💡 Interrupção mínima durante rollback"
else
    log "   ⚠️  DOWNTIME ELEVADO"
    log "   💡 Processo pode ser otimizado"
fi

log ""
log "🎯 PRÓXIMOS PASSOS:"
log "   • Sistema restaurado para PHP 8.3"
log "   • Pronto para novos testes ou demonstrações"
log "   • Dados salvos em: $LOG_FILE"

echo ""
echo "🎉 Rollback concluído com sucesso!"
echo "📄 Detalhes salvos em: $LOG_FILE"
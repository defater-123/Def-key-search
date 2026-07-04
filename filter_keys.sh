#!/bin/bash

# ============================================
# VPN KEY FILTER v6.0 - РАБОТАЕТ С WorkKey.txt
# Первый запуск: скачивает key1.txt
# Последующие: проверяет только WorkKey.txt
# ============================================

echo "========================================="
echo "VPN Key Filter v6.0 (Smart Mode)"
echo "Время запуска: $(date)"
echo "========================================="

# ----- НАСТРОЙКИ -----
SOURCE_URL="https://github.com/defater-123/Def-key-search/raw/refs/heads/main/key1.txt"
WORK_FILE="WorkKey.txt"
SOURCE_FILE="key1.txt"
TIMEOUT_PER_KEY=5
MAX_TOTAL_TIME=900  # 15 минут

# ----- ПРОВЕРЯЕМ, СУЩЕСТВУЕТ ЛИ WorkKey.txt -----
echo ""
if [ -f "$WORK_FILE" ] && [ -s "$WORK_FILE" ]; then
    echo "📂 Найден существующий $WORK_FILE с $(wc -l < $WORK_FILE) ключами"
    echo "🔄 Буду проверять только его (не скачивая новые ключи)"
    KEYS_TO_CHECK="$WORK_FILE"
    IS_FIRST_RUN=false
else
    echo "📥 WorkKey.txt не найден или пуст. Первый запуск!"
    echo "⬇️  Скачиваю $SOURCE_URL..."
    curl -L -o "$SOURCE_FILE" "$SOURCE_URL"
    
    if [ ! -s "$SOURCE_FILE" ]; then
        echo "❌ ОШИБКА: Не удалось скачать ключи!"
        exit 1
    fi
    
    echo "✅ Скачано $(wc -l < $SOURCE_FILE) ключей"
    KEYS_TO_CHECK="$SOURCE_FILE"
    IS_FIRST_RUN=true
fi

# ----- УСТАНОВКА XRAY -----
echo ""
echo "📦 Проверяю наличие Xray..."

if ! command -v xray &> /dev/null; then
    echo "  ⬇️  Устанавливаю Xray..."
    wget -q https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -O xray.zip
    unzip -q xray.zip
    chmod +x xray
    sudo mv xray /usr/local/bin/
    rm -f xray.zip
    echo "  ✅ Xray установлен"
else
    echo "  ✅ Xray уже установлен"
fi

# ----- ФУНКЦИЯ ПРОВЕРКИ КЛЮЧА -----
check_key() {
    local key="$1"
    local key_num="$2"
    
    # Создаем временный конфиг
    cat > "/tmp/config_${key_num}.json" << EOF
{
  "log": {"loglevel": "error"},
  "inbounds": [{"port": 1080, "protocol": "socks"}],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
    
    timeout "$TIMEOUT_PER_KEY" xray run \
        -config "/tmp/config_${key_num}.json" \
        -outbound "$key" \
        > /dev/null 2>&1
    
    local result=$?
    rm -f "/tmp/config_${key_num}.json"
    return $result
}

# ----- ПРОВЕРКА КЛЮЧЕЙ -----
TOTAL=$(wc -l < "$KEYS_TO_CHECK")
echo ""
echo "🔍 Начинаю проверку $TOTAL ключей..."
echo "⏱️  Таймаут на ключ: ${TIMEOUT_PER_KEY}с"
echo "⏱️  Максимальное время: ${MAX_TOTAL_TIME}с (15 минут)"
echo ""

START_TIME=$(date +%s)
ALIVE=0
DEAD=0
COUNT=0
> "alive_temp.txt"

while IFS= read -r key; do
    # Проверяем время
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [ "$ELAPSED" -gt "$MAX_TOTAL_TIME" ]; then
        echo ""
        echo "⏰ Достигнут лимит времени (15 минут)"
        echo "   Проверено: $COUNT из $TOTAL"
        break
    fi
    
    if [ -z "$key" ]; then
        continue
    fi
    
    COUNT=$((COUNT + 1))
    PERCENT=$((COUNT * 100 / TOTAL))
    echo -ne "\r  ⏳ $COUNT/$TOTAL ($PERCENT%) | ✅ $ALIVE | ❌ $DEAD | ⏱️  ${ELAPSED}с"
    
    if check_key "$key" "$COUNT"; then
        echo "$key" >> "alive_temp.txt"
        ALIVE=$((ALIVE + 1))
    else
        DEAD=$((DEAD + 1))
    fi
    
done < "$KEYS_TO_CHECK"

echo "" # Переход на новую строку

# ----- СОХРАНЯЕМ РЕЗУЛЬТАТ -----
mv "alive_temp.txt" "$WORK_FILE"

# Финальная статистика
TOTAL_TIME=$(( $(date +%s) - START_TIME ))
MINUTES=$((TOTAL_TIME / 60))
SECONDS=$((TOTAL_TIME % 60))
FINAL_COUNT=$(wc -l < "$WORK_FILE")

echo ""
echo "========================================="
echo "📊 РЕЗУЛЬТАТЫ:"
echo "   Источник: $KEYS_TO_CHECK"
echo "   Проверено: $COUNT"
echo "   ✅ Живых: $ALIVE"
echo "   ❌ Мертвых: $DEAD"
echo "   📁 Сохранено в: $WORK_FILE ($FINAL_COUNT ключей)"
echo "   ⏱️  Время: ${MINUTES}м ${SECONDS}с"
echo "========================================="

# Если ключей нет - скачиваем новые
if [ ! -s "$WORK_FILE" ]; then
    echo ""
    echo "⚠️  Все ключи мертвы! Скачиваю свежие..."
    curl -L -o "$SOURCE_FILE" "$SOURCE_URL"
    echo "✅ Скачано $(wc -l < $SOURCE_FILE) ключей"
    echo "🔄 Запустите workflow снова для проверки новых ключей"
fi

# Удаляем временные файлы
rm -f "$SOURCE_FILE" 2>/dev/null

echo ""
echo "✅ Работа скрипта завершена"

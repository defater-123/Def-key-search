#!/bin/bash

# ============================================
# VPN KEY FILTER v9.0 - УВЕЛИЧЕННОЕ ВРЕМЯ
# Проверяет ключи через Xray с таймаутом 10с
# ============================================

echo "========================================="
echo "VPN Key Filter v9.0 (Увеличенный таймаут)"
echo "Время запуска: $(date)"
echo "========================================="

# ----- НАСТРОЙКИ -----
SOURCE_URL="https://github.com/defater-123/Def-key-search/raw/refs/heads/main/key1.txt"
WORK_FILE="WorkKey.txt"
SOURCE_FILE="key1.txt"
TIMEOUT_PER_KEY=10  # ← УВЕЛИЧИЛ ДО 10 СЕКУНД
MAX_TOTAL_TIME=1800 # ← 30 МИНУТ (для 150 ключей)

echo ""
echo "📋 НАСТРОЙКИ:"
echo "   Таймаут на ключ: ${TIMEOUT_PER_KEY}с"
echo "   Максимальное время: ${MAX_TOTAL_TIME}с (30 минут)"
echo ""

# ----- ШАГ 1: ПРОВЕРКА ФАЙЛОВ -----
echo "🔍 ШАГ 1: Проверка наличия ключей..."

if [ -f "$WORK_FILE" ] && [ -s "$WORK_FILE" ]; then
    COUNT=$(wc -l < "$WORK_FILE")
    echo "✅ Найден существующий $WORK_FILE ($COUNT ключей)"
    KEYS_TO_CHECK="$WORK_FILE"
    IS_FIRST_RUN=false
else
    echo "📥 WorkKey.txt не найден. Скачиваю ключи впервые..."
    curl -L -o "$SOURCE_FILE" "$SOURCE_URL"
    
    if [ ! -s "$SOURCE_FILE" ]; then
        echo "❌ ОШИБКА: Не удалось скачать ключи!"
        exit 1
    fi
    
    COUNT=$(wc -l < "$SOURCE_FILE")
    echo "✅ Скачано $COUNT ключей"
    KEYS_TO_CHECK="$SOURCE_FILE"
    IS_FIRST_RUN=true
fi

# ----- ШАГ 2: УСТАНОВКА XRAY -----
echo ""
echo "🔧 ШАГ 2: Установка Xray..."

if ! command -v xray &> /dev/null; then
    echo "⬇️  Скачиваю Xray..."
    wget -q https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -O xray.zip
    unzip -q xray.zip
    chmod +x xray
    sudo mv xray /usr/local/bin/
    rm -f xray.zip
    echo "✅ Xray установлен"
else
    echo "✅ Xray уже установлен"
fi

# ----- ШАГ 3: ФУНКЦИЯ ПРОВЕРКИ (ЧЕРЕЗ XRAY) -----
check_key() {
    local key="$1"
    local num="$2"
    
    # Создаем временный конфиг
    cat > "/tmp/config_${num}.json" << EOF
{
  "log": {"loglevel": "error"},
  "inbounds": [{"port": 1080, "protocol": "socks"}],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
    
    # Запускаем Xray с увеличенным таймаутом
    # Добавляем --trace для отладки (покажет ошибки)
    timeout "$TIMEOUT_PER_KEY" xray run \
        -config "/tmp/config_${num}.json" \
        -outbound "$key" \
        > /dev/null 2>&1
    
    local result=$?
    rm -f "/tmp/config_${num}.json"
    return $result
}

# ----- ШАГ 4: ПРОВЕРКА КЛЮЧЕЙ -----
TOTAL=$(wc -l < "$KEYS_TO_CHECK")
echo ""
echo "🚀 ШАГ 3: Проверка $TOTAL ключей через Xray"
echo "========================================="
echo "   ⏱️  Таймаут на ключ: ${TIMEOUT_PER_KEY}с"
echo "   ⏱️  Максимальное время: ${MAX_TOTAL_TIME}с"
echo "   📊 Ключей к проверке: $TOTAL"
echo "========================================="
echo ""

START_TIME=$(date +%s)
ALIVE=0
DEAD=0
COUNT=0
> "alive_temp.txt"

# Создаем лог-файл
LOG_FILE="check_log.txt"
> "$LOG_FILE"

while IFS= read -r key; do
    # Проверка времени
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [ "$ELAPSED" -gt "$MAX_TOTAL_TIME" ]; then
        echo ""
        echo "⏰ Достигнут лимит времени ($MAX_TOTAL_TIME с)"
        echo "   ➜ Проверено $COUNT из $TOTAL ключей"
        break
    fi
    
    if [ -z "$key" ]; then
        continue
    fi
    
    COUNT=$((COUNT + 1))
    PERCENT=$((COUNT * 100 / TOTAL))
    
    # Показываем прогресс
    echo -ne "\r  ⏳ $COUNT/$TOTAL ($PERCENT%) | ✅ $ALIVE | ❌ $DEAD | ⏱️  ${ELAPSED}с"
    
    # Засекаем время проверки конкретного ключа
    KEY_START=$(date +%s)
    
    if check_key "$key" "$COUNT"; then
        KEY_TIME=$(( $(date +%s) - KEY_START ))
        echo "$key" >> "alive_temp.txt"
        ALIVE=$((ALIVE + 1))
        echo "✅ Ключ #$COUNT ЖИВ (${KEY_TIME}с)" >> "$LOG_FILE"
    else
        KEY_TIME=$(( $(date +%s) - KEY_START ))
        DEAD=$((DEAD + 1))
        echo "❌ Ключ #$COUNT МЕРТВ (${KEY_TIME}с)" >> "$LOG_FILE"
    fi
    
done < "$KEYS_TO_CHECK"

echo "" # Переход на новую строку

# ----- ШАГ 5: СОХРАНЕНИЕ РЕЗУЛЬТАТА -----
mv "alive_temp.txt" "$WORK_FILE"
FINAL_COUNT=$(wc -l < "$WORK_FILE")

# Считаем время
TOTAL_TIME=$(( $(date +%s) - START_TIME ))
MINUTES=$((TOTAL_TIME / 60))
SECONDS=$((TOTAL_TIME % 60))

echo ""
echo "========================================="
echo "📊 РЕЗУЛЬТАТЫ:"
echo "   Проверено ключей: $COUNT"
echo "   ✅ Живых: $ALIVE"
echo "   ❌ Мертвых: $DEAD"
echo "   📁 Сохранено в WorkKey.txt ($FINAL_COUNT ключей)"
echo "   ⏱️  Общее время: ${MINUTES}м ${SECONDS}с"
echo "   📋 Детальный лог: $LOG_FILE"
echo "========================================="

# Если все мертвы
if [ ! -s "$WORK_FILE" ]; then
    echo ""
    echo "⚠️  Все ключи мертвы! Скачиваю свежие..."
    curl -L -o "$SOURCE_FILE" "$SOURCE_URL"
    echo "✅ Скачано $(wc -l < $SOURCE_FILE) новых ключей"
    echo "   ➜ Запустите workflow снова"
fi

# Удаляем временные файлы
rm -f "$SOURCE_FILE" 2>/dev/null

echo ""
echo "✅ Работа скрипта завершена"

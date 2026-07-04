#!/bin/bash

# ============================================
# VPN KEY FILTER v10.0 - ПРОВЕРКА ЧЕРЕЗ CURL
# ============================================

echo "========================================="
echo "VPN Key Filter v10.0 (Curl Mode)"
echo "Время запуска: $(date)"
echo "========================================="

# ----- НАСТРОЙКИ -----
SOURCE_URL="https://github.com/defater-123/Def-key-search/raw/refs/heads/main/key1.txt"
WORK_FILE="WorkKey.txt"
SOURCE_FILE="key1.txt"
TIMEOUT=10
MAX_TOTAL_TIME=1800

echo ""
echo "📋 НАСТРОЙКИ:"
echo "   Таймаут на ключ: ${TIMEOUT}с"
echo "   Максимальное время: ${MAX_TOTAL_TIME}с (30 минут)"
echo ""

# ----- ШАГ 1: ПРОВЕРКА ФАЙЛОВ -----
echo "🔍 ШАГ 1: Проверка наличия ключей..."

if [ -f "$WORK_FILE" ] && [ -s "$WORK_FILE" ]; then
    COUNT=$(wc -l < "$WORK_FILE")
    echo "✅ Найден существующий $WORK_FILE ($COUNT ключей)"
    KEYS_TO_CHECK="$WORK_FILE"
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
fi

# ----- ШАГ 2: ФУНКЦИЯ ПРОВЕРКИ КЛЮЧА (через curl) -----
check_key() {
    local key="$1"
    
    # Извлекаем IP, порт и протокол из ключа
    # Поддерживает: vless://, vmess://, trojan://, shadowsocks://
    
    # Пробуем извлечь IP/домен и порт
    if [[ "$key" =~ @([^:]+):([0-9]+) ]]; then
        # vless://uuid@IP:PORT
        IP="${BASH_REMATCH[1]}"
        PORT="${BASH_REMATCH[2]}"
        PROTOCOL="vless"
    elif [[ "$key" =~ ://([^@]+)@([^:]+):([0-9]+) ]]; then
        # vmess://uuid@IP:PORT
        IP="${BASH_REMATCH[2]}"
        PORT="${BASH_REMATCH[3]}"
        PROTOCOL="vmess"
    elif [[ "$key" =~ ^([a-zA-Z0-9.-]+):([0-9]+) ]]; then
        # IP:PORT
        IP="${BASH_REMATCH[1]}"
        PORT="${BASH_REMATCH[2]}"
        PROTOCOL="direct"
    else
        return 1
    fi
    
    # Пробуем подключиться через curl (проверяем доступность порта)
    # Используем --socks5 если это vless/vmess, иначе просто проверяем порт
    if [[ "$PROTOCOL" == "vless" ]] || [[ "$PROTOCOL" == "vmess" ]]; then
        # Для vless/vmess используем socks5 прокси
        timeout $TIMEOUT curl -s --socks5-hostname "$IP:$PORT" https://google.com -o /dev/null -w "%{http_code}" 2>/dev/null | grep -q "200"
        return $?
    else
        # Для обычных ключей проверяем доступность порта
        timeout $TIMEOUT nc -zv "$IP" "$PORT" > /dev/null 2>&1
        return $?
    fi
}

# ----- ШАГ 3: ПРОВЕРКА КЛЮЧЕЙ -----
TOTAL=$(wc -l < "$KEYS_TO_CHECK")
echo ""
echo "🚀 ШАГ 2: Проверка $TOTAL ключей через curl"
echo "========================================="
echo "   ⏱️  Таймаут на ключ: ${TIMEOUT}с"
echo "   ⏱️  Максимальное время: ${MAX_TOTAL_TIME}с"
echo "========================================="
echo ""

START_TIME=$(date +%s)
ALIVE=0
DEAD=0
COUNT=0
> "alive_temp.txt"
> "check_log.txt"

while IFS= read -r key; do
    # Проверка времени
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [ "$ELAPSED" -gt "$MAX_TOTAL_TIME" ]; then
        echo ""
        echo "⏰ Достигнут лимит времени ($MAX_TOTAL_TIME с)"
        break
    fi
    
    if [ -z "$key" ]; then
        continue
    fi
    
    COUNT=$((COUNT + 1))
    PERCENT=$((COUNT * 100 / TOTAL))
    
    # Засекаем время проверки
    KEY_START=$(date +%s)
    
    # Показываем прогресс
    echo -ne "\r  ⏳ $COUNT/$TOTAL ($PERCENT%) | ✅ $ALIVE | ❌ $DEAD | ⏱️  ${ELAPSED}с"
    
    # Проверяем ключ
    if check_key "$key"; then
        KEY_TIME=$(( $(date +%s) - KEY_START ))
        echo "$key" >> "alive_temp.txt"
        ALIVE=$((ALIVE + 1))
        echo "✅ Ключ #$COUNT ЖИВ (${KEY_TIME}с)" >> "check_log.txt"
    else
        KEY_TIME=$(( $(date +%s) - KEY_START ))
        DEAD=$((DEAD + 1))
        echo "❌ Ключ #$COUNT МЕРТВ (${KEY_TIME}с)" >> "check_log.txt"
    fi
    
done < "$KEYS_TO_CHECK"

echo "" # Переход на новую строку

# ----- ШАГ 4: СОХРАНЕНИЕ РЕЗУЛЬТАТА -----
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
echo "   📋 Детальный лог: check_log.txt"
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

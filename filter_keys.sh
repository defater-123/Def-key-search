#!/bin/bash

# ============================================
# VPN KEY FILTER v7.0 - С УВЕДОМЛЕНИЯМИ
# ============================================

echo "========================================="
echo "🔐 VPN Key Filter v7.0 (Старт)"
echo "========================================="
echo "📅 Время: $(date)"
echo "👤 Пользователь: ${{ github.actor }}"
echo ""

# ----- НАСТРОЙКИ -----
SOURCE_URL="https://github.com/defater-123/Def-key-search/raw/refs/heads/main/key1.txt"
WORK_FILE="WorkKey.txt"
SOURCE_FILE="key1.txt"
TIMEOUT_PER_KEY=5
MAX_TOTAL_TIME=900  # 15 минут

# ----- ШАГ 1: ПРОВЕРКА ФАЙЛОВ -----
echo "🔍 ШАГ 1: Проверка наличия ключей..."
echo ""

if [ -f "$WORK_FILE" ] && [ -s "$WORK_FILE" ]; then
    COUNT=$(wc -l < "$WORK_FILE")
    echo "✅ Найден существующий $WORK_FILE"
    echo "   ➜ Ключей в нем: $COUNT"
    echo "   ➜ Буду проверять только его (не скачивая новые)"
    KEYS_TO_CHECK="$WORK_FILE"
    IS_FIRST_RUN=false
else
    echo "📥 WorkKey.txt не найден или пуст. Это первый запуск!"
    echo "⬇️  Скачиваю ключи из: $SOURCE_URL"
    echo ""
    
    curl -L -o "$SOURCE_FILE" "$SOURCE_URL"
    
    if [ ! -s "$SOURCE_FILE" ]; then
        echo ""
        echo "❌ ОШИБКА: Не удалось скачать ключи!"
        echo "   ➜ Проверьте ссылку в SOURCE_URL"
        echo "   ➜ Или загрузите key1.txt вручную"
        exit 1
    fi
    
    COUNT=$(wc -l < "$SOURCE_FILE")
    echo ""
    echo "✅ Успешно скачано $COUNT ключей"
    KEYS_TO_CHECK="$SOURCE_FILE"
    IS_FIRST_RUN=true
fi

# ----- ШАГ 2: УСТАНОВКА XRAY -----
echo ""
echo "🔧 ШАГ 2: Подготовка Xray..."
echo ""

if ! command -v xray &> /dev/null; then
    echo "⬇️  Xray не найден, устанавливаю..."
    wget -q https://github.com/XTLS/Xray-core/releases/latest/download/Xray-linux-64.zip -O xray.zip
    unzip -q xray.zip
    chmod +x xray
    sudo mv xray /usr/local/bin/
    rm -f xray.zip
    echo "✅ Xray установлен успешно"
else
    echo "✅ Xray уже установлен"
fi

# ----- ШАГ 3: ПРОВЕРКА КЛЮЧЕЙ -----
TOTAL=$(wc -l < "$KEYS_TO_CHECK")
echo ""
echo "🚀 ШАГ 3: Проверка ключей"
echo "========================================="
echo "   Всего ключей к проверке: $TOTAL"
echo "   Таймаут на ключ: ${TIMEOUT_PER_KEY}с"
echo "   Максимальное время: ${MAX_TOTAL_TIME}с (15 минут)"
echo "========================================="
echo ""

START_TIME=$(date +%s)
ALIVE=0
DEAD=0
COUNT=0
> "alive_temp.txt"

# Создаем файл для лога
LOG_FILE="check_log.txt"
> "$LOG_FILE"

while IFS= read -r key; do
    # Проверяем время
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    if [ "$ELAPSED" -gt "$MAX_TOTAL_TIME" ]; then
        echo ""
        echo "⏰ Достигнут лимит времени (15 минут)"
        echo "   ➜ Проверено: $COUNT из $TOTAL"
        echo "   ➜ Пропущено: $((TOTAL - COUNT)) ключей"
        break
    fi
    
    if [ -z "$key" ]; then
        continue
    fi
    
    COUNT=$((COUNT + 1))
    PERCENT=$((COUNT * 100 / TOTAL))
    
    # Показываем прогресс в реальном времени
    echo -ne "\r  ⏳ Прогресс: $COUNT/$TOTAL ($PERCENT%) | ✅ Живых: $ALIVE | ❌ Мертвых: $DEAD | ⏱️  ${ELAPSED}с"
    
    # Проверка ключа через Xray
    cat > "/tmp/config_${COUNT}.json" << EOF
{
  "log": {"loglevel": "error"},
  "inbounds": [{"port": 1080, "protocol": "socks"}],
  "outbounds": [{"protocol": "freedom"}]
}
EOF
    
    if timeout "$TIMEOUT_PER_KEY" xray run -config "/tmp/config_${COUNT}.json" -outbound "$key" > /dev/null 2>&1; then
        echo "$key" >> "alive_temp.txt"
        ALIVE=$((ALIVE + 1))
        echo "✅ $(date +%H:%M:%S) - Ключ #$COUNT ЖИВ" >> "$LOG_FILE"
    else
        DEAD=$((DEAD + 1))
        echo "❌ $(date +%H:%M:%S) - Ключ #$COUNT МЕРТВ" >> "$LOG_FILE"
    fi
    
    rm -f "/tmp/config_${COUNT}.json"
    
done < "$KEYS_TO_CHECK"

echo "" # Переход на новую строку

# ----- ШАГ 4: СОХРАНЕНИЕ РЕЗУЛЬТАТА -----
echo ""
echo "💾 ШАГ 4: Сохранение результатов..."
echo ""

mv "alive_temp.txt" "$WORK_FILE"
FINAL_COUNT=$(wc -l < "$WORK_FILE")

# Считаем время
TOTAL_TIME=$(( $(date +%s) - START_TIME ))
MINUTES=$((TOTAL_TIME / 60))
SECONDS=$((TOTAL_TIME % 60))

# ----- ШАГ 5: ФИНАЛЬНЫЙ ОТЧЕТ -----
echo "========================================="
echo "📊 ФИНАЛЬНЫЙ ОТЧЕТ"
echo "========================================="
echo "📁 Источник ключей: $KEYS_TO_CHECK"
echo "📊 Всего проверено: $COUNT"
echo "✅ Живых ключей: $ALIVE"
echo "❌ Мертвых ключей: $DEAD"
echo "📁 Сохранено в файл: $WORK_FILE ($FINAL_COUNT ключей)"
echo "⏱️  Затраченное время: ${MINUTES}м ${SECONDS}с"
echo "========================================="
echo ""

# ----- ШАГ 6: ДОПОЛНИТЕЛЬНЫЕ ДЕЙСТВИЯ -----
if [ ! -s "$WORK_FILE" ]; then
    echo "⚠️  ВНИМАНИЕ: Все ключи мертвы!"
    echo "   ➜ Скачиваю свежие ключи из источника..."
    curl -L -o "$SOURCE_FILE" "$SOURCE_URL"
    NEW_COUNT=$(wc -l < "$SOURCE_FILE")
    echo "   ➜ Скачано $NEW_COUNT новых ключей"
    echo "   ➜ Запустите workflow снова для их проверки"
else
    echo "✅ Готово! В файле $WORK_FILE сохранены рабочие ключи."
    echo "   ➜ Их можно скопировать и использовать."
fi

echo ""
echo "📋 Детальный лог проверки сохранен в: $LOG_FILE"
echo "   ➜ Откройте его, чтобы увидеть статус каждого ключа"
echo ""

# Удаляем временные файлы
rm -f "$SOURCE_FILE" 2>/dev/null

echo "========================================="
echo "🏁 Скрипт завершил работу"
echo "========================================="

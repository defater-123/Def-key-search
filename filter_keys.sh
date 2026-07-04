#!/bin/bash

# ============================================
# VPN KEY FILTER v5.0 - ДЛЯ 1000 КЛЮЧЕЙ
# Оптимизирован с запасом 15 минут на задержки
# ============================================

echo "========================================="
echo "VPN Key Filter v5.0 (Xray + 15min buffer)"
echo "Время запуска: $(date)"
echo "========================================="

# ----- НАСТРОЙКИ (меняйте здесь) -----

# ССЫЛКА НА ВАШ РЕПОЗИТОРИЙ С КЛЮЧАМИ
SOURCE_URL="https://raw.githubusercontent.com/ВАШ_АККАУНТ/ВАШ_РЕПО/main/"

# ИМЯ ВЫХОДНОГО ФАЙЛА
OUTPUT_FILE="WorkKey.txt"

# ТАЙМАУТ НА КЛЮЧ (секунды) - увеличен для надежности
TIMEOUT_PER_KEY=5

# МАКСИМАЛЬНОЕ ВРЕМЯ ВСЕЙ ПРОВЕРКИ (секунды) - 15 минут запас
MAX_TOTAL_TIME=900  # 15 минут = 900 секунд

# ----- НЕ МЕНЯТЬ НИЖЕ ЭТОЙ СТРОКИ -----

# Создаем временные файлы
TEMP_DIR="temp_xray"
mkdir -p "$TEMP_DIR"
> "$OUTPUT_FILE"
> "alive_temp.txt"

# Скачиваем файлы с ключами
echo ""
echo "📥 Скачиваю ключи из репозитория..."

# Список файлов для скачивания (добавьте свои)
FILES=(
    "key1.txt"
    "key2.txt"
    "key3.txt"
    "key4.txt"
    "key5.txt"
)

ALL_KEYS="all_keys_temp.txt"
> "$ALL_KEYS"

for file in "${FILES[@]}"; do
    echo "  ⬇️  Скачиваю $file..."
    curl -s -L -o "${TEMP_DIR}/$file" "${SOURCE_URL}${file}"
    
    if [ -s "${TEMP_DIR}/$file" ]; then
        cat "${TEMP_DIR}/$file" >> "$ALL_KEYS"
        echo "  ✅ Добавлено $(wc -l < ${TEMP_DIR}/$file) ключей"
    else
        echo "  ⚠️  Файл $file не найден или пуст"
    fi
done

# Удаляем дубликаты и пустые строки
sort -u "$ALL_KEYS" -o "$ALL_KEYS"
sed -i '/^[[:space:]]*$/d' "$ALL_KEYS"

TOTAL=$(wc -l < "$ALL_KEYS")
echo ""
echo "📊 Всего уникальных ключей: $TOTAL"

# Если ключей больше 1000 - обрезаем до 1000 (для безопасности)
if [ "$TOTAL" -gt 1000 ]; then
    echo "⚠️  Обнаружено более 1000 ключей ($TOTAL)"
    echo "✂️  Обрезаю до первых 1000 для сохранения времени..."
    head -n 1000 "$ALL_KEYS" > "${ALL_KEYS}.tmp"
    mv "${ALL_KEYS}.tmp" "$ALL_KEYS"
    TOTAL=1000
    echo "✅ Теперь ключей: $TOTAL"
fi

# ----- УСТАНОВКА XRAY -----
echo ""
echo "📦 Устанавливаю Xray..."

if ! command -v xray &> /dev/null; then
    echo "  ⬇️  Скачиваю Xray..."
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
    local total="$3"
    
    # Создаем временный конфиг для Xray
    cat > "${TEMP_DIR}/config_${key_num}.json" << EOF
{
  "log": {
    "loglevel": "error"
  },
  "inbounds": [
    {
      "port": 1080,
      "protocol": "socks"
    }
  ],
  "outbounds": [
    {
      "protocol": "freedom"
    }
  ]
}
EOF
    
    # Запускаем Xray с проверкой ключа
    timeout "$TIMEOUT_PER_KEY" xray run \
        -config "${TEMP_DIR}/config_${key_num}.json" \
        -outbound "$key" \
        > /dev/null 2>&1
    
    local result=$?
    
    # Удаляем временный конфиг
    rm -f "${TEMP_DIR}/config_${key_num}.json"
    
    return $result
}

# ----- ОСНОВНАЯ ПРОВЕРКА (с таймером) -----
echo ""
echo "🔍 Начинаю проверку $TOTAL ключей..."
echo "⏱️  Таймаут на ключ: ${TIMEOUT_PER_KEY}с"
echo "⏱️  Максимальное время: ${MAX_TOTAL_TIME}с (15 минут)"
echo ""

START_TIME=$(date +%s)
ALIVE=0
DEAD=0
COUNT=0
SKIPPED=0

# Проверяем каждый ключ
while IFS= read -r key; do
    # Проверяем время
    CURRENT_TIME=$(date +%s)
    ELAPSED=$((CURRENT_TIME - START_TIME))
    
    # Если прошло больше 15 минут - прерываем
    if [ "$ELAPSED" -gt "$MAX_TOTAL_TIME" ]; then
        echo ""
        echo "⏰ Достигнут лимит времени (15 минут)"
        echo "   Проверено: $COUNT | Пропущено: $(($TOTAL - $COUNT))"
        SKIPPED=$(($TOTAL - $COUNT))
        break
    fi
    
    if [ -z "$key" ]; then
        continue
    fi
    
    COUNT=$((COUNT + 1))
    
    # Вывод прогресса (обновляется в той же строке)
    PERCENT=$((COUNT * 100 / TOTAL))
    echo -ne "\r  ⏳ Прогресс: $COUNT/$TOTAL ($PERCENT%) | ✅ Живых: $ALIVE | ❌ Мертвых: $DEAD | ⏱️  ${ELAPSED}с"
    
    # Проверяем ключ через Xray
    if check_key "$key" "$COUNT" "$TOTAL"; then
        echo "$key" >> "alive_temp.txt"
        ALIVE=$((ALIVE + 1))
    else
        DEAD=$((DEAD + 1))
    fi
    
done < "$ALL_KEYS"

echo "" # Переход на новую строку

# ----- СОХРАНЕНИЕ РЕЗУЛЬТАТА -----
mv "alive_temp.txt" "$OUTPUT_FILE"

# Финальная статистика
FINAL_TOTAL=$(wc -l < "$OUTPUT_FILE")
TOTAL_TIME=$(( $(date +%s) - START_TIME ))
MINUTES=$((TOTAL_TIME / 60))
SECONDS=$((TOTAL_TIME % 60))

echo ""
echo "========================================="
echo "📊 ИТОГОВЫЕ РЕЗУЛЬТАТЫ:"
echo "   Всего ключей в начале: $TOTAL"
echo "   Проверено ключей: $COUNT"
echo "   Пропущено (из-за времени): $SKIPPED"
echo "   ✅ Живых ключей: $ALIVE"
echo "   ❌ Мертвых ключей: $DEAD"
echo "   📁 Сохранено в: $OUTPUT_FILE ($FINAL_TOTAL ключей)"
echo "   ⏱️  Общее время: ${MINUTES}м ${SECONDS}с"
echo "========================================="

# Если все ключи мертвы - предупреждение
if [ ! -s "$OUTPUT_FILE" ]; then
    echo ""
    echo "⚠️  ВНИМАНИЕ: Все ключи мертвы!"
    echo "   Добавьте новые файлы key1.txt, key2.txt и т.д."
fi

# ----- ОЧИСТКА -----
rm -rf "$TEMP_DIR"
rm -f "$ALL_KEYS"

echo ""
echo "✅ Работа скрипта завершена"

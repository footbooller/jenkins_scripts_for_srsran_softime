#!/bin/bash
set -euo pipefail

# === 1. ДОБАВЛЯЕМ /usr/local/bin В PATH ===
export PATH="/usr/local/bin:$PATH"

# === 2. ПРОВЕРКА НАЛИЧИЯ БИНАРНИКОВ ===
for bin in srsenb srsepc srsue; do
    if ! command -v "$bin" >/dev/null 2>&1; then
        echo "ОШИБКА: $bin не найден в PATH!"
        echo "Текущий PATH: $PATH"
        exit 1
    fi
done

echo "Очистка namespace..."
ip netns delete ue1 2>/dev/null || true

echo "Запуск EPC..."
srsepc > epc.log 2>&1 &

echo "Запуск eNB..."
srsenb -c /etc/srsran/enb.conf > enb.log 2>&1 &

echo "Настройка и запуск UE в namespace ue1..."
ip netns add ue1
ip netns exec ue1 sysctl -w net.ipv4.conf.all.accept_local=1
ip netns exec ue1 sysctl -w net.ipv4.ip_forward=1
ip netns exec ue1 srsue -c /etc/srsran/ue.conf > ue.log 2>&1 &

echo "Ожидание подключения UE (30 сек)..."
sleep 30

echo "=== Лог UE (последние 30 строк) ==="
tail -n 30 ue.log || true

echo "=== Лог eNB (последние 30 строк) ==="
tail -n 30 enb.log || true

echo "=== Лог EPC (последние 30 строк) ==="
tail -n 30 epc.log || true

# Проверка пинга
echo "Проверка пинга из UE..."
if ip netns exec ue1 ping -c 4 192.168.3.1 > ping.log 2>&1; then
    echo "ПИНГ УСПЕШЕН!"
    cat ping.log
else
    echo "ПИНГ НЕ ПРОШЁЛ"
    cat ping.log
fi

# Очистка
echo "Очистка..."
ip netns delete ue1 2>/dev/null || true
pkill -f srsue || true
pkill -f srsenb || true
pkill -f srsepc || true

echo "ТЕСТ ЗАВЕРШЁН"
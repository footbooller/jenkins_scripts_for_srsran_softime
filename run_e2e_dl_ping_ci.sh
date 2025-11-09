#!/bin/bash
set -euo pipefail

# ==== 1. PATH ====
export PATH="/usr/local/bin:$PATH"

# ==== 2. Проверка бинарников ====
for bin in srsenb srsepc srsue; do
    command -v "$bin" >/dev/null || { echo "ОШИБКА: $bin не найден!"; exit 1; }
done

echo "Очистка namespace..."
ip netns delete ue1 2>/dev/null || true

echo "Запуск EPC..."
srsepc > epc.log 2>&1 &

echo "Запуск eNB..."
srsenb -c /etc/srsran/enb.conf > enb.log 2>&1 &

echo "Запуск UE в namespace ue1..."
ip netns add ue1
ip netns exec ue1 sysctl -w net.ipv4.conf.all.accept_local=1
ip netns exec ue1 sysctl -w net.ipv4.ip_forward=1
ip netns exec ue1 srsue -c /etc/srsran/ue.conf > ue.log 2>&1 &

# Ждём подключения UE (примерно 30 сек)
sleep 30

echo "=== ue.log (последние 30 строк) ==="
tail -n 30 ue.log

echo "=== enb.log (последние 30 строк) ==="
tail -n 30 enb.log

echo "=== epc.log (последние 30 строк) ==="
tail -n 30 epc.log

# Пинг (пример)
ip netns exec ue1 ping -c 4 192.168.3.1 || true

# Очистка
ip netns delete ue1 || true
pkill -f srsue || true
pkill -f srsenb || true
pkill -f srsepc || true
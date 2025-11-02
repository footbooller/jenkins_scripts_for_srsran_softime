#!/bin/bash

set -e

echo "Очистка namespace..."
sudo ip netns delete ue1 || true

echo "Запуск EPC..."
sudo srsepc /etc/srsran/epc.conf > epc.log 2>&1 &
sleep 5

echo "Запуск eNB..."
sudo srsenb /etc/srsran/enb.conf > enb.log 2>&1 &
sleep 5

echo "Запуск UE в namespace ue1..."
sudo ip netns add ue1
sudo ip link add if0-ue1 type dummy
sudo ip link set if0-ue1 netns ue1
sudo ip netns exec ue1 ip link set if0-ue1 up
sudo ip netns exec ue1 ip addr add 127.0.0.2/8 dev lo
sudo ip netns exec ue1 sysctl -w net.ipv4.conf.all.accept_local=1
sudo ip netns exec ue1 sysctl -w net.ipv4.ip_forward=1

sudo ip netns exec ue1 srsue /etc/srsran/ue.conf \
    --gw.netns=ue1 \
    --log.all_level=info \
    > ue.log 2>&1 &

sleep 30

# Проверка RRC
if ! grep -q "RRC Connected" ue.log; then
    echo "ОШИБКА: UE не подключился!"
    echo "=== ue.log (последние 30 строк) ==="
    tail -30 ue.log
    pkill -f srsepc || true
    pkill -f srsenb || true
    pkill -f srsue || true
    sudo ip netns delete ue1 || true
    exit 1
fi

echo "UE подключился! Проверка пинга..."

# Пинг в EPC (172.16.0.1)
sudo ip netns exec ue1 ping -c 10 172.16.0.1 > ping.log 2>&1

if grep -q "100% packet loss" ping.log; then
    echo "ПИНГ НЕ ПРОШЁЛ!"
    cat ping.log
    pkill -f srsepc || true
    pkill -f srsenb || true
    pkill -f srsue || true
    sudo ip netns delete ue1 || true
    exit 1
fi

echo "ПИНГ УСПЕШЕН! Тест пройден."

# Очистка
pkill -f srsepc || true
pkill -f srsenb || true
pkill -f srsue || true
sudo ip netns delete ue1 || true
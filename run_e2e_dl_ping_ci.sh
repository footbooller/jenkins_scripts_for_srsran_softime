#!/bin/bash

# Очистка namespace...
echo "Очистка namespace..."
sudo ip netns delete ue1 || true

# Запуск EPC...
echo "Запуск EPC..."
sudo srsepc /etc/srsran/epc.conf > epc.log 2>&1 &
sleep 5

# Запуск eNB...
echo "Запуск eNB..."
sudo srsenb /etc/srsran/enb.conf > enb.log 2>&1 &
sleep 5

# Запуск UE...
echo "Запуск UE..."
sudo ip netns add ue1
sudo ip link add name if0-ue1 type dummy
sudo ip link set if0-ue1 netns ue1
sudo ip netns exec ue1 ip link set if0-ue1 up
sudo ip netns exec ue1 ip addr add 127.0.0.2/8 dev lo
sudo ip netns exec ue1 sysctl -w net.ipv4.conf.all.accept_local=1
sudo ip netns exec ue1 sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec ue1 srsue /etc/srsran/ue.conf --gw.netns=ue1 --log.all_level=debug > ue.log 2>&1 &
sleep 30  # Увеличено для стабильного RRC подключения

# Проверка подключения UE
if ! grep -q "RRC Connected" ue.log; then
    echo "ОШИБКА: UE не подключился! Последние 20 строк ue.log:"
    tail -20 ue.log
    pkill -f srsepc || true
    pkill -f srsenb || true
    pkill -f srsue || true
    sudo ip netns delete ue1 || true
    exit 1
fi

# Запуск ping (из доки: UE IP 172.16.0.2, ping EPC 172.16.0.1)
echo "Запуск ping..."
sudo ip netns exec ue1 ping -c 10 172.16.0.1 > ping.log 2>&1

# Проверка ping
if grep -q "100% packet loss" ping.log; then
    echo "ОШИБКА: Пинг не прошёл! Лог ping:"
    cat ping.log
    pkill -f srsepc || true
    pkill -f srsenb || true
    pkill -f srsue || true
    sudo ip netns delete ue1 || true
    exit 1
fi

echo "Тест пройден успешно!"

# Очистка
pkill -f srsepc || true
pkill -f srsenb || true
pkill -f srsue || true
sudo ip netns delete ue1 || true
#!/bin/bash

# Очистка namespace...
echo "Очистка namespace..."
sudo ip netns delete ue1 || true

# Запуск EPC...
echo "Запуск EPC..."
srsepc /etc/srsran/epc.conf > epc.log 2>&1 &
sleep 5

# Запуск eNB...
echo "Запуск eNB..."
srsenb /etc/srsran/enb.conf > enb.log 2>&1 &
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
sudo ip netns exec ue1 srsue /etc/srsran/ue.conf --rf.device_name=zmq --rf.device_args="tx_port=tcp://*:2003,rx_port=tcp://localhost:2002" --log.all_level=debug > ue.log 2>&1 &
sleep 10

# Проверка подключения UE
if ! grep -q "RRC Connected" ue.log; then
    echo "ОШИБКА: UE не подключился! Последние 20 строк ue.log:"
    tail -20 ue.log
    exit 1
fi

# Запуск ping...
echo "Запуск ping..."
sudo ip netns exec ue1 ping -c 10 45.45.45.1 > ping.log 2>&1  # Пример IP из документации

# Проверка ping
if grep -q "100% packet loss" ping.log; then
    echo "ОШИБКА: Пинг не прошёл!"
    exit 1
fi

echo "Тест пройден успешно!"

# Очистка
killall srsepc srsenb srsue || true
sudo ip netns delete ue1 || true
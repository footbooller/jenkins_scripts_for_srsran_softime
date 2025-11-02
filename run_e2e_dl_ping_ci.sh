#!/bin/bash

# Очистка namespace...
echo "Очистка namespace..."
sudo ip netns delete ue1 || true

# Запуск EPC...
echo "Запуск EPC..."
sudo srsepc /etc/srsran/epc.conf > epc.log 2>&1 &
sleep 10  # Дать время на bind

# Запуск eNB...
echo "Запуск eNB..."
sudo srsenb /etc/srsran/enb.conf --rf.device_name=zmq --rf.device_args="fail_on_disconnect=true,tx_port=tcp://*:2000,rx_port=tcp://localhost:2001,id=enb,base_srate=23.04e6" > enb.log 2>&1 &
sleep 10  # Дать время на S1 connect

# Запуск UE...
echo "Запуск UE в namespace ue1..."
sudo ip netns add ue1
sudo ip link add name if0-ue1 type dummy
sudo ip link set if0-ue1 netns ue1
sudo ip netns exec ue1 ip link set if0-ue1 up
sudo ip netns exec ue1 ip addr add 127.0.0.2/8 dev lo
sudo ip netns exec ue1 sysctl -w net.ipv4.conf.all.accept_local=1
sudo ip netns exec ue1 sysctl -w net.ipv4.ip_forward=1
sudo ip netns exec ue1 srsue /etc/srsran/ue.conf --rf.device_name=zmq --rf.device_args="tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6" --gw.netns=ue1 --log.all_level=debug > ue.log 2>&1 &
sleep 90  # Увеличено для attach и reconnection

# Проверка подключения UE
if ! grep -q "RRC Connected" ue.log; then
    echo "ОШИБКА: UE не подключился!"
    echo "=== ue.log (последние 30 строк) ==="
    tail -30 ue.log
    echo "=== enb.log (последние 30 строк) ==="
    tail -30 enb.log
    echo "=== epc.log (последние 30 строк) ==="
    tail -30 epc.log
    sudo pkill -f srsepc || true
    sudo pkill -f srsenb || true
    sudo pkill -f srsue || true
    sudo ip netns delete ue1 || true
    exit 1
fi

# Запуск ping (к DNS 8.8.8.8 для проверки интернета)
echo "Запуск ping..."
sudo ip netns exec ue1 ping -c 10 8.8.8.8 > ping.log 2>&1

# Проверка ping
if grep -q "100% packet loss" ping.log; then
    echo "ОШИБКА: Пинг не прошёл! Лог ping:"
    cat ping.log
    sudo pkill -f srsepc || true
    sudo pkill -f srsenb || true
    sudo pkill -f srsue || true
    sudo ip netns delete ue1 || true
    exit 1
fi

echo "Тест пройден успешно!"

# Очистка
sudo pkill -f srsepc || true
sudo pkill -f srsenb || true
sudo pkill -f srsue || true
sudo ip netns delete ue1 || true
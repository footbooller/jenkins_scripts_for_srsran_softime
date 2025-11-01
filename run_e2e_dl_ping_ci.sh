#!/bin/bash

# Очистка namespace...
echo "Очистка namespace..."
sudo ip netns delete ue1 || true

# Запуск EPC...
echo "Запуск EPC..."
sudo srsepc /etc/srsran/epc.conf > epc.log 2>&1 &
EPC_PID=$!
sleep 5

# Запуск eNB...
echo "Запуск eNB..."
srsenb /etc/srsran/enb.conf --rf.device_name=zmq --rf.device_args="fail_on_disconnect=true,tx_port=tcp://*:2000,rx_port=tcp://localhost:2001,id=enb,base_srate=23.04e6" > enb.log 2>&1 &
ENB_PID=$!
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
sudo ip netns exec ue1 srsue /etc/srsran/ue.conf --rf.device_name=zmq --rf.device_args="tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6" --gw.netns=ue1 --log.all_level=debug > ue.log 2>&1 &
UE_PID=$!
sleep 20  # Увеличил sleep для подключения

# Проверка подключения UE
if ! grep -q "RRC Connected" ue.log; then
    echo "ОШИБКА: UE не подключился! Последние 20 строк ue.log:"
    tail -20 ue.log
    kill $EPC_PID $ENB_PID $UE_PID || true
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
    kill $EPC_PID $ENB_PID $UE_PID || true
    sudo ip netns delete ue1 || true
    exit 1
fi

echo "Тест пройден успешно!"

# Очистка
kill $EPC_PID $ENB_PID $UE_PID || true
sudo ip netns delete ue1 || true
#!/bin/bash
set -e

echo "Очистка namespace..."
sudo ip netns delete ue1 || true

echo "Запуск EPC..."
sudo srsepc /etc/srsran/epc.conf > epc.log 2>&1 &
sleep 10

echo "Запуск eNB..."
sudo srsenb /etc/srsran/enb.conf \
    --rf.device_name=zmq \
    --rf.device_args="fail_on_disconnect=true,tx_port=tcp://*:2000,rx_port=tcp://localhost:2001,id=enb,base_srate=23.04e6" \
    > enb.log 2>&1 &
sleep 10

echo "Запуск UE в namespace ue1..."
sudo ip netns add ue1
sudo ip link add name if0-ue1 type dummy
sudo ip link set if0-ue1 netns ue1
sudo ip netns exec ue1 ip link set if0-ue1 up
sudo ip netns exec ue1 ip addr add 127.0.0.2/8 dev lo
sudo ip netns exec ue1 sysctl -w net.ipv4.conf.all.accept_local=1
sudo ip netns exec ue1 sysctl -w net.ipv4.ip_forward=1

sudo ip netns exec ue1 srsue /etc/srsran/ue.conf \
    --rf.device_name=zmq \
    --rf.device_args="tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6" \
    --gw.netns=ue1 --log.all_level=debug > ue.log 2>&1 &
sleep 90   # достаточно для attach

# ---------- Проверка RRC ----------
if ! grep -q "RRC Connected\|Random Access Complete" ue.log; then
    echo "ОШИБКА: UE не подключился!"
    echo "=== ue.log (tail -30) ==="
    tail -30 ue.log
    echo "=== enb.log (tail -30) ==="
    tail -30 enb.log
    echo "=== epc.log (tail -30) ==="
    tail -30 epc.log
    sudo pkill -f srsepc || true
    sudo pkill -f srsenb || true
    sudo pkill -f srsue || true
    sudo ip netns delete ue1 || true
    exit 1
fi

# ---------- Пинг ----------
echo "Запуск ping..."
sudo ip netns exec ue1 ping -c 10 172.16.0.1 > ping.log 2>&1

if grep -q "100% packet loss" ping.log; then
    echo "ОШИБКА: Пинг не прошёл!"
    cat ping.log
    sudo pkill -f srsepc || true
    sudo pkill -f srsenb || true
    sudo pkill -f srsue || true
    sudo ip netns delete ue1 || true
    exit 1
fi

echo "Тест пройден успешно!"
echo "=== ping.log (last 10) ==="
tail -10 ping.log

# ---------- Очистка ----------
sudo pkill -f srsepc || true
sudo pkill -f srsenb || true
sudo pkill -f srsue || true
sudo ip netns delete ue1 || true
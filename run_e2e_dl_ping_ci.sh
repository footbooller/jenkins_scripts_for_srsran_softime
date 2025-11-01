#!/bin/bash
set -e

# === Проверка сборки ===
if [ ! -d "srsRAN_4G/build" ]; then
  echo "ОШИБКА: Сборка не найдена! Запустите setup_env_ci.sh"
  exit 1
fi

cd srsRAN_4G/build

# === Очистка namespace (doc 13.3.6) ===
echo "Очистка namespace..."
sudo ip netns delete ue1 || true
sudo ip netns add ue1

# === Запуск EPC (doc 13.3.2) ===
echo "Запуск EPC..."
sudo ./srsepc/src/srsepc --epc.config_file=../../configs/epc.conf > epc.log 2>&1 &
EPC_PID=$!
sleep 10

# === Запуск eNB (doc 13.3.3) ===
echo "Запуск eNB..."
./srsenb/src/srsenb \
  --enb.config_file=../../configs/enb.conf \
  --rf.device_name=zmq \
  --rf.device_args="fail_on_disconnect=true,tx_port=tcp://*:2000,rx_port=tcp://localhost:2001,id=enb,base_srate=23.04e6" \
  > enb.log 2>&1 &
ENB_PID=$!
sleep 10

# === Запуск UE (doc 13.3.4) ===
echo "Запуск UE..."
sudo ./srsue/src/srsue \
  --ue.config_file=../../configs/ue.conf \
  --rf.device_name=zmq \
  --rf.device_args="tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6" \
  --gw.netns=ue1 \
  > ue.log 2>&1 &
UE_PID=$!
sleep 40  # Ждём RRC подключения

# === Проверка RRC Connected ===
if ! grep -q "RRC Connected" ue.log; then
  echo "ОШИБКА: UE не подключился! (RRC не установлен)"
  echo "=== Последние 20 строк ue.log ==="
  tail -n 20 ue.log
  exit 1
fi
echo "UE подключился (RRC Connected)"

# === Проверка DL ping (doc 13.3.5) ===
echo "Проверка DL: ping 172.16.0.2 → 172.16.0.1"
ping -c 10 -i 0.2 172.16.0.2 > ping_dl.log 2>&1
if ! grep -q "0% packet loss" ping_dl.log; then
  echo "ОШИБКА: Потери в DL!"
  cat ping_dl.log
  exit 1
fi
echo "DL: 0% потерь"

# === Проверка UL ping (из netns ue1) ===
echo "Проверка UL: ping 172.16.0.1 → 172.16.0.2"
sudo ip netns exec ue1 ping -c 10 -i 0.2 172.16.0.1 > ping_ul.log 2>&1
if ! grep -q "0% packet loss" ping_ul.log; then
  echo "ОШИБКА: Потери в UL!"
  cat ping_ul.log
  exit 1
fi
echo "UL: 0% потерь"

# === УСПЕХ ===
echo "ТЕСТ ПРОЙДЕН! (соответствует srsRAN 4G Release 23.11, Chapter 13)"
echo "  • 13.3.1: netns ue1"
echo "  • 13.3.2: EPC запущен"
echo "  • 13.3.3: eNB с ZMQ"
echo "  • 13.3.4: UE с ZMQ + netns"
echo "  • 13.3.5: DL ping 0% loss"
echo "  • 13.3.6: Очистка"

# === Очистка ===
echo "Очистка процессов и netns..."
kill $UE_PID 2>/dev/null || true
sleep 3
kill $ENB_PID 2>/dev/null || true
sleep 3
kill $EPC_PID 2>/dev/null || true
sudo ip netns delete ue1 || true

# === Сохранение логов для Jenkins ===
echo "Логи сохранены: epc.log, enb.log, ue.log, ping_dl.log, ping_ul.log"
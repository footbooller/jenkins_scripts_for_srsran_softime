#!/bin/bash
set -e

echo "=== Установка системных зависимостей (один раз) ==="
sudo apt update
sudo apt install -y \
  build-essential cmake git wget curl \
  libboost-all-dev libfftw3-dev libmbedtls-dev \
  libconfig++-dev libsctp-dev libpcsclite-dev \
  iproute2 net-tools

echo "=== Клонирование и сборка libzmq (doc 13.2) ==="
if [ ! -d "libzmq" ]; then
  git clone https://github.com/zeromq/libzmq.git
else
  (cd libzmq && git pull)
fi
cd libzmq
./autogen.sh && ./configure && make -j$(nproc)
sudo make install
sudo ldconfig
cd ..

echo "=== Клонирование и сборка czmq (doc 13.2) ==="
if [ ! -d "czmq" ]; then
  git clone https://github.com/zeromq/czmq.git
else
  (cd czmq && git pull)
fi
cd czmq
./autogen.sh && ./configure && make -j$(nproc)
sudo make install
sudo ldconfig
cd ..

echo "=== Клонирование и сборка srsRAN_4G (doc 13.2) ==="
if [ ! -d "srsRAN_4G" ]; then
  git clone https://github.com/srsran/srsRAN_4G.git
else
  (cd srsRAN_4G && git pull)
fi
cd srsRAN_4G
mkdir -p build && cd build
cmake .. -DCMAKE_BUILD_TYPE=Release
make -j$(nproc)

echo "=== Сборка завершена ==="
# === Генерация конфигурационных файлов (doc 13.3) ===
echo "=== Генерация конфигурационных файлов ==="
mkdir -p configs

# Копируем из исходников (на уровень выше build/)
cp ../srsepc/srsepc.conf.example configs/epc.conf
cp ../srsenb/enb.conf.example configs/enb.conf
cp ../srsue/ue.conf.example configs/ue.conf

# === Настройка UE ===
sed -i 's/imsi = .*/imsi = 001010000000001/' configs/ue.conf
sed -i 's/apn = .*/apn = srsapn/' configs/ue.conf

# === Настройка RF в конфигах (ZMQ) ===
# UE
sed -i '/\[rf\]/,/^\[/ s/device_name = .*/device_name = zmq/' configs/ue.conf
sed -i '/\[rf\]/,/^\[/ s|device_args = .*|device_args = "tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6"|' configs/ue.conf

# eNB
sed -i '/\[rf\]/,/^\[/ s/device_name = .*/device_name = zmq/' configs/enb.conf
sed -i '/\[rf\]/,/^\[/ s|device_args = .*|device_args = "fail_on_disconnect=true,tx_port=tcp://*:2000,rx_port=tcp://localhost:2001,id=enb,base_srate=23.04e6"|' configs/enb.conf

echo "Конфиги созданы: configs/epc.conf, enb.conf, ue.conf"
# === EPC — дефолт подходит ===
echo "Конфиги готовы в ./configs/"
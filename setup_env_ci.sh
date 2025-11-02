#!/bin/bash

set -e  # Остановка при любой ошибке

# === Установка системных зависимостей ===
echo "=== Установка системных зависимостей (один раз) ==="
sudo apt-get update
sudo apt-get install -y \
    build-essential iproute2 libfftw3-dev libsctp-dev \
    libboost-all-dev libconfig++-dev libmbedtls-dev \
    cmake curl git libpcsclite-dev net-tools wget

# === Клонирование и сборка libzmq ===
echo "=== Клонирование и сборка libzmq (doc 13.2) ==="
if [ ! -d "libzmq" ]; then
    git clone https://github.com/zeromq/libzmq.git
fi
cd libzmq
git checkout v4.3.5
./autogen.sh
./configure
make -j$(nproc)
sudo make install
sudo ldconfig
cd ..

# === Клонирование и сборка czmq ===
echo "=== Клонирование и сборка czmq (doc 13.2) ==="
if [ ! -d "czmq" ]; then
    git clone https://github.com/zeromq/czmq.git
fi
cd czmq
git checkout v4.2.1
./autogen.sh
./configure
make -j$(nproc)
sudo make install
sudo ldconfig
cd ..

# === Клонирование и сборка srsRAN_4G ===
echo "=== Клонирование и сборка srsRAN_4G (doc 13.2) ==="
if [ ! -d "srsRAN_4G" ]; then
    git clone https://github.com/srsran/srsRAN_4G.git
fi
cd srsRAN_4G
git checkout release_23_11
mkdir -p build
cd build
cmake .. -DENABLE_ZMQ=ON
make -j$(nproc)
sudo make install
sudo ldconfig
cd ../..

# === УСТАНОВКА КОНФИГУРАЦИОННЫХ ФАЙЛОВ В /etc/srsran/ ===
echo "=== Установка конфигурационных файлов в /etc/srsran/ ==="

sudo mkdir -p /etc/srsran

# Копируем .example файлы из подпапок srsenb/, srsue/, srsepc/
sudo cp srsRAN_4G/srsenb/enb.conf.example /etc/srsran/enb.conf
sudo cp srsRAN_4G/srsue/ue.conf.example   /etc/srsran/ue.conf
sudo cp srsRAN_4G/srsepc/epc.conf.example /etc/srsran/epc.conf
sudo cp srsRAN_4G/srsenb/rr.conf.example  /etc/srsran/rr.conf
sudo cp srsRAN_4G/srsenb/sib.conf.example /etc/srsran/sib.conf
sudo cp srsRAN_4G/srsepc/user_db.csv.example /etc/srsran/user_db.csv

echo "Конфиги скопированы из srsRAN_4G/srsenb/, srsue/, srsepc/"

# === НАСТРОЙКА ZMQ В КОНФИГАХ (doc 13.3) ===
echo "=== Настройка ZMQ в конфигах ==="

# eNB: ZMQ RF
sudo sed -i '/\[rf\]/a device_name = zmq' /etc/srsran/enb.conf
sudo sed -i '/\[rf\]/a device_args = tx_port=tcp://*:2000,rx_port=tcp://localhost:2001,id=enb,base_srate=23.04e6' /etc/srsran/enb.conf

# UE: ZMQ RF
sudo sed -i '/\[rf\]/a device_name = zmq' /etc/srsran/ue.conf
sudo sed -i '/\[rf\]/a device_args = tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6' /etc/srsran/ue.conf

# EPC: локальные адреса
sudo sed -i 's/mme_bind_addr.*/mme_bind_addr = 127.0.1.1/' /etc/srsran/epc.conf
sudo sed -i 's/gtpu_bind_addr.*/gtpu_bind_addr = 127.0.1.1/' /etc/srsran/epc.conf

echo "ZMQ настроен в enb.conf и ue.conf"

# === ПРОВЕРКА ===
echo "=== Содержимое /etc/srsran/ ==="
ls -la /etc/srsran/
echo "=== Сборка и настройка завершены ==="
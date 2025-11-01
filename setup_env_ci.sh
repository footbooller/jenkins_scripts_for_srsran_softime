#!/bin/bash

# === Установка системных зависимостей (один раз) ===
echo "=== Установка системных зависимостей (один раз) ==="
sudo apt-get update
sudo apt-get install -y build-essential iproute2 libfftw3-dev libsctp-dev libboost-all-dev libconfig++-dev libmbedtls-dev cmake curl git libpcsclite-dev net-tools wget

# === Клонирование и сборка libzmq (doc 13.2) ===
echo "=== Клонирование и сборка libzmq (doc 13.2) ==="
if [ ! -d "libzmq" ]; then
    git clone https://github.com/zeromq/libzmq.git
fi
cd libzmq
git checkout v4.3.5  # Версия, совместимая с srsRAN
./autogen.sh
./configure
make -j$(nproc)
sudo make install
sudo ldconfig
cd ..

# === Клонирование и сборка czmq (doc 13.2) ===
echo "=== Клонирование и сборка czmq (doc 13.2) ==="
if [ ! -d "czmq" ]; then
    git clone https://github.com/zeromq/czmq.git
fi
cd czmq
git checkout v4.2.1  # Совместимая версия
./autogen.sh
./configure
make -j$(nproc)
sudo make install
sudo ldconfig
cd ..

# === Клонирование и сборка srsRAN_4G (doc 13.2) ===
echo "=== Клонирование и сборка srsRAN_4G (doc 13.2) ==="
if [ ! -d "srsRAN_4G" ]; then
    git clone https://github.com/srsran/srsRAN_4G.git
fi
cd srsRAN_4G
git checkout release_23_11  # Release 23.11 для Chapter 13
mkdir build
cd build
cmake .. -DENABLE_ZMQ=ON  # Включаем ZMQ
make -j$(nproc)
sudo make install  # Устанавливаем в систему (/usr/local/)
sudo ldconfig
cd ../..

# === Настройка конфигов для ZMQ (doc 13.3) ===
echo "=== Настройка конфигов для ZMQ (doc 13.3) ==="
sudo mkdir -p /etc/srsran
sudo cp srsRAN_4G/configs/*.conf /etc/srsran/  # Копируйте из исходников или вашей configs/
# Настройка ZMQ в enb.conf
sudo sed -i 's/device_name = uhd/device_name = zmq/g' /etc/srsran/enb.conf
sudo sed -i 's/device_args = auto/device_args = tx_port=tcp:\/\/*:2001,rx_port=tcp:\/\/localhost:2000,id=enb,fail_on_disconnect=true/g' /etc/srsran/enb.conf
# Настройка ZMQ в ue.conf
sudo sed -i 's/device_name = uhd/device_name = zmq/g' /etc/srsran/ue.conf
sudo sed -i 's/device_args = auto/device_args = tx_port=tcp:\/\/*:2003,rx_port=tcp:\/\/localhost:2002,id=ue,fail_on_disconnect=true/g' /etc/srsran/ue.conf
# Другие конфиги (epc.conf, rr.conf и т.д.) оставьте по умолчанию или настройте по необходимости

echo "=== Сборка завершена ==="
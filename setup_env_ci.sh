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

# === Установка конфигурационных файлов (из документации) ===
echo "=== Установка конфигурационных файлов в /etc/srsran/ ==="
# Скрипт установки конфигов устанавливается в /usr/local/bin после make install
if [ -f /usr/local/bin/srsran_4g_install_configs.sh ]; then
    sudo /usr/local/bin/srsran_4g_install_configs.sh service  # Для system-wide в /etc/srsran/
else
    # Если скрипт не найден, копируем вручную из исходников (примеры в srsRAN_4G/cmake/install_scripts/)
    sudo mkdir -p /etc/srsran
    sudo cp ../cmake/install_scripts/*.conf.example /etc/srsran/
    sudo mv /etc/srsran/enb.conf.example /etc/srsran/enb.conf
    sudo mv /etc/srsran/ue.conf.example /etc/srsran/ue.conf
    sudo mv /etc/srsran/epc.conf.example /etc/srsran/epc.conf
    sudo mv /etc/srsran/rr.conf.example /etc/srsran/rr.conf
    sudo mv /etc/srsran/sib.conf.example /etc/srsran/sib.conf
    sudo mv /etc/srsran/user_db.csv.example /etc/srsran/user_db.csv
    echo "Конфиги скопированы вручную из example файлов."
fi

# === Настройка конфигов для ZMQ (doc 13.3) ===
echo "=== Настройка конфигов для ZMQ (doc 13.3) ==="
# Настройка ZMQ в enb.conf (но документация рекомендует command-line args; модифицируем для persist)
sudo sed -i '/\[rf\]/a device_name = zmq' /etc/srsran/enb.conf
sudo sed -i '/\[rf\]/a device_args = fail_on_disconnect=true,tx_port=tcp://*:2000,rx_port=tcp://localhost:2001,id=enb,base_srate=23.04e6' /etc/srsran/enb.conf

# Настройка ZMQ в ue.conf
sudo sed -i '/\[rf\]/a device_name = zmq' /etc/srsran/ue.conf
sudo sed -i '/\[rf\]/a device_args = tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6' /etc/srsran/ue.conf

# Убедимся, что EPC использует default subnet (172.16.0.0/24 по доке)
sudo sed -i 's/mme_bind_addr = .*/mme_bind_addr = 127.0.1.1/' /etc/srsran/epc.conf
sudo sed -i 's/gtpu_bind_addr = .*/gtpu_bind_addr = 127.0.1.1/' /etc/srsran/epc.conf

echo "=== Сборка и настройка завершены ==="
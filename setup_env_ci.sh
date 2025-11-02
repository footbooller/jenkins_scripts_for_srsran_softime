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

# === Установка конфигурационных файлов в /etc/srsran/ ===
echo "=== Установка конфигурационных файлов в /etc/srsran/ ==="
# Проверяем и используем скрипт установки, если он доступен
if [ -f /usr/local/bin/srsran_4g_install_configs.sh ]; then
    sudo /usr/local/bin/srsran_4g_install_configs.sh service  # System-wide установка в /etc/srsran/
else
    # Копируем вручную из поддиректорий
    sudo mkdir -p /etc/srsran
    sudo cp ../srsenb/enb.conf.example /etc/srsran/enb.conf || { echo "Ошибка копирования enb.conf.example"; exit 1; }
    sudo cp ../srsenb/rr.conf.example /etc/srsran/rr.conf || true
    sudo cp ../srsenb/sib.conf.example /etc/srsran/sib.conf || true
    sudo cp ../srsenb/rb.conf.example /etc/srsran/rb.conf || true
    sudo cp ../srsue/ue.conf.example /etc/srsran/ue.conf || { echo "Ошибка копирования ue.conf.example"; exit 1; }
    sudo cp ../srsepc/epc.conf.example /etc/srsran/epc.conf || { echo "Ошибка копирования epc.conf.example"; exit 1; }
    sudo cp ../srsepc/user_db.csv.example /etc/srsran/user_db.csv || true
    echo "Конфиги скопированы вручную из srsenb/, srsue/, srsepc/."
fi

# === Настройка конфигов для ZMQ (doc 13.3) ===
echo "=== Настройка конфигов для ZMQ (doc 13.3) ==="
# Добавляем [rf] секцию в enb.conf, если её нет
if ! grep -q "\[rf\]" /etc/srsran/enb.conf; then
    sudo bash -c 'cat <<EOF >> /etc/srsran/enb.conf
[rf]
device_name = zmq
device_args = fail_on_disconnect=true,tx_port=tcp://*:2000,rx_port=tcp://localhost:2001,id=enb,base_srate=23.04e6
EOF'
fi

# Добавляем [rf] секцию в ue.conf, если её нет
if ! grep -q "\[rf\]" /etc/srsran/ue.conf; then
    sudo bash -c 'cat <<EOF >> /etc/srsran/ue.conf
[rf]
device_name = zmq
device_args = tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6
EOF'
fi

# Отключаем канал-эмуляторы (не нужны для ZMQ) и удаляем недопустимые опции
sudo sed -i '/\[channel\]/,/\[/ s/enable = true/enable = false/' /etc/srsran/ue.conf
sudo sed -i '/\[channel\]/,/\[/ s/enable = true/enable = false/' /etc/srsran/enb.conf
# Удаляем 'device_args' под [channel.ul.hst] или похожих
sudo sed -i '/channel.ul.hst.device_args/d' /etc/srsran/ue.conf
sudo sed -i '/channel.ul.hst.device_args/d' /etc/srsran/enb.conf

# Фикс S1 connection: Устанавливаем все bind/addrs на 127.0.0.1
sudo sed -i 's/mme_addr = .*/mme_addr = 127.0.0.1/' /etc/srsran/enb.conf || true
sudo sed -i 's/gtp_bind_addr = .*/gtp_bind_addr = 127.0.0.1/' /etc/srsran/enb.conf || true
sudo sed -i 's/s1c_bind_addr = .*/s1c_bind_addr = 127.0.0.1/' /etc/srsran/enb.conf || true
sudo sed -i 's/mme_bind_addr = .*/mme_bind_addr = 127.0.0.1/' /etc/srsran/epc.conf || true
sudo sed -i 's/gtpu_bind_addr = .*/gtpu_bind_addr = 127.0.0.1/' /etc/srsran/epc.conf || true

# Проверка содержимого /etc/srsran/
echo "=== Содержимое /etc/srsran/ после настройки ==="
sudo ls -la /etc/srsran/

echo "=== Сборка и настройка завершены ==="
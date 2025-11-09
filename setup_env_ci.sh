#!/bin/bash
set -euo pipefail

echo "=== Обновление системы (Ubuntu 24.04) ==="
apt-get update
apt-get install -y \
    git cmake build-essential libfftw3-dev libmbedtls-dev \
    libsctp-dev libzmq3-dev libczmq-dev libconfig++-dev \
    libboost-system-dev libboost-test-dev libboost-thread-dev \
    libboost-program-options-dev libboost-filesystem-dev \
    libusb-1.0-0-dev libpcsclite-dev pcsc-tools pcscd \
    libuhd-dev uhd-host

echo "=== Установка ZMQ из исходников ==="
cd /tmp
git clone --depth 1 https://github.com/zeromq/libzmq.git
cd libzmq
mkdir build && cd build
cmake ..
make -j$(nproc)
make install
ldconfig

echo "=== Установка CZMQ из исходников ==="
cd /tmp
git clone --depth 1 https://github.com/zeromq/czmq.git
cd czmq
mkdir build && cd build
cmake ..
make -j$(nproc)
make install
ldconfig

echo "=== Клонирование srsRAN_4G ==="
cd /workspace
git clone --depth 1 https://github.com/srsRAN/srsRAN_4G.git
cd srsRAN_4G

echo "=== Сборка srsRAN_4G ==="
mkdir -p build
cd build
cmake .. -DCMAKE_INSTALL_PREFIX=/usr/local
make -j$(nproc)

echo "=== УСТАНОВКА srsRAN_4G в /usr/local/bin ==="
make install
ldconfig

echo "=== Проверка установки srsRAN ==="
ls -l /usr/local/bin/srs* || true
echo "srsenb: $(which srsenb || echo 'НЕ НАЙДЕН')"
echo "srsepc: $(which srsepc || echo 'НЕ НАЙДЕН')"
echo "srsue:  $(which srsue  || echo 'НЕ НАЙДЕН')"

echo "=== Создание директории /etc/srsran/ ==="
mkdir -p /etc/srsran

echo "=== Копирование конфигов в /etc/srsran/ ==="
cp ../*.conf.example /etc/srsran/ 2>/dev/null || true
cp ../*.csv.example /etc/srsran/ 2>/dev/null || true

# Переименуем .example → без суффикса
for f in /etc/srsran/*.example; do
    [ -f "$f" ] && mv "$f" "${f%.example}"
done

echo "=== Перечисление /etc/srsran/ после копирования ==="
ls -l /etc/srsran/

echo "=== Настройка ZMQ (doc 13.3) ==="
# Пример: заменяем rf_driver = "zmq" в enb.conf, ue.conf
sed -i 's/rf_driver = "uhd"/rf_driver = "zmq"/g' /etc/srsran/enb.conf || true
sed -i 's/device_name = "uhd"/device_name = "zmq"/g' /etc/srsran/ue.conf || true

echo "=== УСТАНОВКА ЗАВЕРШЕНА ==="
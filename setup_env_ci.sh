#!/bin/bash
set -e  # Остановка на ошибках

# === Установка системных зависимостей ===
echo "=== Установка системных зависимостей (один раз) ==="
sudo apt update
sudo apt install -y build-essential iproute2 libfftw3-dev libsctp-dev libboost-all-dev libconfig++-dev libmbedtls-dev cmake curl git libpcsclite-dev net-tools wget

# === Клонирование и сборка libzmq ===
echo "=== Клонирование и сборка libzmq (doc 13.2) ==="
git clone https://github.com/zeromq/libzmq.git || true  # Если уже склонировано
cd libzmq
./autogen.sh
./configure
make -j$(nproc)
sudo make install
sudo ldconfig
cd ..

# === Клонирование и сборка czmq ===
echo "=== Клонирование и сборка czmq (doc 13.2) ==="
git clone https://github.com/zeromq/czmq.git || true
cd czmq
./autogen.sh
./configure
make -j$(nproc)
sudo make install
sudo ldconfig
cd ..

# === Клонирование и сборка srsRAN_4G ===
echo "=== Клонирование и сборка srsRAN_4G (doc 13.2) ==="
git clone https://github.com/srsran/srsRAN_4G.git srsran || true  # Укажите правильный URL, если форк
cd srsran
mkdir -p build
cd build
cmake ..
make -j$(nproc)
sudo make install
sudo ldconfig
cd ../..  # Вернуться в корень workspace

# === Генерация конфигурационных файлов ===
echo "=== Генерация конфигурационных файлов ==="
cd srsran  # Предполагая, что репозиторий склонирован как 'srsran' (проверьте в вашем git clone)
if [ ! -f "srsepc/epc.conf.example" ]; then
    echo "Ошибка: Файл srsepc/epc.conf.example не найден! Проверьте репозиторий srsRAN_4G."
    exit 1
fi
cp srsepc/epc.conf.example srsepc/epc.conf
cp srsenb/enb.conf.example srsenb/enb.conf
cp srsue/ue.conf.example srsue/ue.conf

# Модифицируем конфиги для ZMQ (doc 13.2: Замена RF на ZMQ)
sed -i 's/device_name = uhd/device_name = zmq/g' srsenb/enb.conf
sed -i 's/device_args = auto/device_args = tx_port=tcp:\/\/*:2001,rx_port=tcp:\/\/localhost:2000,id=enb,base_srate=23.04e6/g' srsenb/enb.conf
sed -i 's/device_name = uhd/device_name = zmq/g' srsue/ue.conf
sed -i 's/device_args = auto/device_args = tx_port=tcp:\/\/*:2003,rx_port=tcp:\/\/localhost:2002,id=ue,base_srate=23.04e6/g' srsue/ue.conf

# Опционально: Установите другие параметры (MCC/MNC, IP для TUN)
sed -i 's/mcc = 001/mcc = 001/g' srsepc/epc.conf  # Пример: Ваш MCC/MNC
sed -i 's/mnc = 01/mnc = 01/g' srsepc/epc.conf
sed -i 's/gtp_bind_addr = 127.0.0.1/gtp_bind_addr = 127.0.0.1/g' srsepc/epc.conf  # Локальный IP

cd ..  # Вернуться в корень workspace
echo "=== Конфигурационные файлы сгенерированы и настроены для ZMQ ==="
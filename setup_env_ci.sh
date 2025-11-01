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
cd srsran  # !!! Фикс: Переходим в директорию srsran перед cp !!!
if [ ! -f "srsepc/srsepc.conf.example" ]; then
    echo "Ошибка: Файл srsepc/srsepc.conf.example не найден! Проверьте репозиторий srsRAN_4G."
    exit 1
fi
cp srsepc/srsepc.conf.example srsepc/srsepc.conf
cp srsenb/enb.conf.example srsenb/enb.conf
cp srsue/ue.conf.example srsue/ue.conf
# Добавьте другие cp, если нужно (например, rr.conf.example, sib.conf.example)
# Опционально: Модифицируйте конфиги для ZMQ (sed -i 's/device_name = uhd/device_name = zmq/g' srsenb/enb.conf)
cd ..  # Вернуться назад
echo "=== Сборка завершена ==="
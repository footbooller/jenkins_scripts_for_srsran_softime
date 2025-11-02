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

# ОТЛАДКА: Показываем структуру репозитория ДО создания build/
echo "=== [ОТЛАДКА] Структура srsRAN_4G ДО создания build/ ==="
ls -R

# Создаём директорию сборки
mkdir -p build
cd build

# ОТЛАДКА: Показываем, где мы находимся и что видим отсюда
echo "=== [ОТЛАДКА] Текущая директория: $(pwd) ==="
echo "=== [ОТЛАДКА] Содержимое родительской директории (../) ==="
ls -la ..

# ОТЛАДКА: Проверяем наличие нужных папок и файлов
echo "=== [ОТЛАДКА] Проверка наличия srsenb/, srsue/, srsepc/ ==="
if [ -d "../srsenb" ]; then
    echo "../srsenb/ — найдена"
    ls ../srsenb/*.example 2>/dev/null || echo "Нет .example файлов в srsenb/"
else
    echo "ОШИБКА: ../srsenb/ НЕ найдена!"
    exit 1
fi

if [ -d "../srsue" ]; then
    echo "../srsue/ — найдена"
    ls ../srsue/*.example 2>/dev/null || echo "Нет .example файлов в srsue/"
else
    echo "ОШИБКА: ../srsue/ НЕ найдена!"
    exit 1
fi

if [ -d "../srsepc" ]; then
    echo "../srsepc/ — найдена"
    ls ../srsepc/*.example 2>/dev/null || echo "Нет .example файлов в srsepc/"
else
    echo "ОШИБКА: ../srsepc/ НЕ найдена!"
    exit 1
fi

# Сборка
cmake .. -DENABLE_ZMQ=ON
make -j$(nproc)
sudo make install
sudo ldconfig

# === Установка конфигурационных файлов в /etc/srsran/ ===
echo "=== Установка конфигурационных файлов в /etc/srsran/ ==="
if [ -f /usr/local/bin/srsran_4g_install_configs.sh ]; then
    echo "Используем встроенный скрипт установки конфигов..."
    sudo /usr/local/bin/srsran_4g_install_configs.sh service
else
    echo "Копируем конфиги вручную..."
    sudo mkdir -p /etc/srsran

    # Копируем с проверкой
    sudo cp ../srsenb/enb.conf.example /etc/srsran/enb.conf || { echo "Ошибка: не удалось скопировать enb.conf.example"; exit 1; }
    sudo cp ../srsue/ue.conf.example /etc/srsran/ue.conf || { echo "Ошибка: не удалось скопировать ue.conf.example"; exit 1; }
    sudo cp ../srsepc/epc.conf.example /etc/srsran/epc.conf || { echo "Ошибка: не удалось скопировать epc.conf.example"; exit 1; }
    sudo cp ../srsenb/rr.conf.example /etc/srsran/rr.conf || true
    sudo cp ../srsenb/sib.conf.example /etc/srsran/sib.conf || true
    sudo cp ../srsepc/user_db.csv.example /etc/srsran/user_db.csv || true

    echo "Конфиги скопированы вручную."
fi

# === Настройка конфигов для ZMQ ===
echo "=== Настройка ZMQ в конфигах ==="
# enb.conf
if ! grep -q "\[rf\]" /etc/srsran/enb.conf; then
    sudo bash -c 'cat <<EOF >> /etc/srsran/enb.conf

[rf]
device_name = zmq
device_args = fail_on_disconnect=true,tx_port=tcp://*:2000,rx_port=tcp://localhost:2001,id=enb,base_srate=23.04e6
EOF'
    echo "ZMQ добавлен в enb.conf"
fi

# ue.conf
if ! grep -q "\[rf\]" /etc/srsran/ue.conf; then
    sudo bash -c 'cat <<EOF >> /etc/srsran/ue.conf

[rf]
device_name = zmq
device_args = tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6
EOF'
    echo "ZMQ добавлен в ue.conf"
fi

# Отключаем channel emulation
sudo sed -i '/\[channel\./ s/enable = true/enable = false/' /etc/srsran/ue.conf
sudo sed -i '/\[channel\./ s/enable = true/enable = false/' /etc/srsran/enb.conf
sudo sed -i '/channel.ul.hst.device_args/d' /etc/srsran/ue.conf

# EPC bind
sudo sed -i 's/mme_bind_addr = .*/mme_bind_addr = 127.0.1.1/' /etc/srsran/epc.conf || true
sudo sed -i 's/gtpu_bind_addr = .*/gtpu_bind_addr = 127.0.1.1/' /etc/srsran/epc.conf || true

# Финальная проверка
echo "=== Содержимое /etc/srsran/ ==="
sudo ls -la /etc/srsran/
echo "=== Первые строки enb.conf ==="
sudo head -20 /etc/srsran/enb.conf
echo "=== Первые строки ue.conf ==="
sudo head -20 /etc/srsran/ue.conf

echo "=== Сборка и настройка завершены ==="
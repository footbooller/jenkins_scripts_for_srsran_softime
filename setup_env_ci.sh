#!/bin/bash
set -e

echo "=== Установка системных зависимостей (один раз) ==="
sudo apt-get update
sudo apt-get install -y build-essential iproute2 libfftw3-dev libsctp-dev \
    libboost-all-dev libconfig++-dev libmbedtls-dev cmake curl git \
    libpcsclite-dev net-tools wget

# ---------- libzmq ----------
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

# ---------- czmq ----------
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

# ---------- srsRAN_4G ----------
echo "=== Клонирование и сборка srsRAN_4G (doc 13.2) ==="
if [ ! -d "srsRAN_4G" ]; then
    git clone https://github.com/srsran/srsRAN_4G.git
fi
cd srsRAN_4G
git checkout release_23_11
mkdir -p build && cd build
cmake .. -DENABLE_ZMQ=ON
make -j$(nproc)
sudo make install
sudo ldconfig
cd ../..

# ---------- Копирование конфигов ----------
echo "=== Установка конфигурационных файлов в /etc/srsran/ ==="
sudo mkdir -p /etc/srsran
sudo cp srsRAN_4G/srsenb/enb.conf.example /etc/srsran/enb.conf
sudo cp srsRAN_4G/srsue/ue.conf.example  /etc/srsran/ue.conf
sudo cp srsRAN_4G/srsepc/epc.conf.example /etc/srsran/epc.conf
sudo cp srsRAN_4G/srsepc/user_db.csv.example /etc/srsran/user_db.csv
sudo cp srsRAN_4G/srsenb/rr.conf.example /etc/srsran/rr.conf || true
sudo cp srsRAN_4G/srsenb/sib.conf.example /etc/srsran/sib.conf || true
sudo cp srsRAN_4G/srsenb/rb.conf.example /etc/srsran/rb.conf || true

# ---------- Настройка ZMQ (TCP, как в Chapter 13) ----------
echo "=== Настройка конфигов для ZMQ (doc 13.3) ==="
if ! grep -q "\[rf\]" /etc/srsran/enb.conf; then
    sudo bash -c 'cat <<EOF >> /etc/srsran/enb.conf
[rf]
device_name = zmq
device_args = fail_on_disconnect=true,tx_port=tcp://*:2000,rx_port=tcp://localhost:2001,id=enb,base_srate=23.04e6
EOF'
fi
if ! grep -q "\[rf\]" /etc/srsran/ue.conf; then
    sudo bash -c 'cat <<EOF >> /etc/srsran/ue.conf
[rf]
device_name = zmq
device_args = tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6
EOF'
fi

# Отключаем канал-эмуляторы
sudo sed -i '/\[channel\]/,/\[/ s/enable = true/enable = false/' /etc/srsran/ue.conf
sudo sed -i '/\[channel\]/,/\[/ s/enable = true/enable = false/' /etc/srsran/enb.conf
sudo sed -i '/channel.ul.hst.device_args/d' /etc/srsran/ue.conf
sudo sed -i '/channel.ul.hst.device_args/d' /etc/srsran/enb.conf

# ---------- S1AP / GTP-U bind на 127.0.0.1 ----------
sudo sed -i 's/mme_addr = .*/mme_addr = 127.0.0.1/' /etc/srsran/enb.conf || true
sudo sed -i 's/gtp_bind_addr = .*/gtp_bind_addr = 127.0.0.1/' /etc/srsran/enb.conf || true
sudo sed -i 's/s1c_bind_addr = .*/s1c_bind_addr = 127.0.0.1/' /etc/srsran/enb.conf || true
sudo sed -i 's/mme_bind_addr = .*/mme_bind_addr = 127.0.0.1/' /etc/srsran/epc.conf || true
sudo sed -i 's/gtpu_bind_addr = .*/gtpu_bind_addr = 127.0.0.1/' /etc/srsran/epc.conf || true

# ---------- USIM (если пусто) ----------
if ! grep -q "90170" /etc/srsran/user_db.csv; then
    echo "ue1,mil,901700000021309,00112233445566778899aabbccddeeff,opc,63bfa50ee6523365ff14c1f45f88737d,8000,000000001234,9,dynamic" \
        | sudo tee -a /etc/srsran/user_db.csv > /dev/null
fi

# ---------- Вывод версии ----------
echo "=== Версия srsRAN_4G: $(git -C srsRAN_4G log -1 --pretty='%h %s') ==="

echo "=== Сборка и настройка завершены ==="
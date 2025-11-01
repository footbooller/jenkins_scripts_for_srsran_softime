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
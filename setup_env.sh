#!/bin/bash

TB_PATH=$PWD
cd ../../..
PROJ_PATH=$PWD
cd $TB_PATH

BUILD_DIR=build

SRS_DIR=srsRAN_4G
LIBZMQ_DIR=libzmq
CZMQ_DIR=czmq

if [ -d "$PROJ_PATH/$BUILD_DIR" ]; then
  echo "Build directory already exist!"
  exit
fi

mkdir -p $PROJ_PATH/$BUILD_DIR

cp -r $SRS_DIR/ $PROJ_PATH/$BUILD_DIR/
cp -r $LIBZMQ_DIR/ $PROJ_PATH/$BUILD_DIR/
cp -r $CZMQ_DIR/ $PROJ_PATH/$BUILD_DIR/

cd $PROJ_PATH/$BUILD_DIR/$LIBZMQ_DIR
./autogen.sh
./configure
make
sudo make install
sudo ldconfig

cd $PROJ_PATH/$BUILD_DIR/$CZMQ_DIR
./autogen.sh
./configure
make
sudo make install
sudo ldconfig

cd $PROJ_PATH/$BUILD_DIR/$SRS_DIR
mkdir build
cd build
cmake ../
make

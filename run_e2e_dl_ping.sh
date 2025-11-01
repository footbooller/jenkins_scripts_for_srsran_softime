#!/bin/bash

TB_PATH=$PWD
cd ../../..
PROJ_PATH=$PWD
cd $TB_PATH

BUILD_DIR=build

SRS_DIR=srsRAN_4G
LIBZMQ_DIR=libzmq
CZMQ_DIR=czmq

if [ ! -d "$PROJ_PATH/$BUILD_DIR" ]; then
  echo "Build directory doesn't exist!"
  exit
fi

cd $PROJ_PATH/$BUILD_DIR/$SRS_DIR/$BUILD_DIR

echo - setup network names -

# to ensure
sudo ip netns delete ue1

sudo ip netns add ue1
sudo ip netns list

echo - running EPC -

gnome-terminal -- bash -c "sudo ./srsepc/src/srsepc"

echo - running ENB -

gnome-terminal -- bash -c "./srsenb/src/srsenb --rf.device_name=zmq --rf.device_args="fail_on_disconnect=true,tx_port=tcp://*:2000,rx_port=tcp://localhost:2001,id=enb,base_srate=23.04e6""

echo - running UE1 -

gnome-terminal -- bash -c "sudo ./srsue/src/srsue --rf.device_name=zmq --rf.device_args="tx_port=tcp://*:2001,rx_port=tcp://localhost:2000,id=ue,base_srate=23.04e6" --gw.netns=ue1"

ping 172.16.0.2

#!/bin/bash

DATE=$1
MODEL=$2
TEST_NUM=$3
PREFIX="${DATE}_${MODEL}-test${TEST_NUM}"

if [ $# -ne 3 ]; then
    echo "Usage:\n"
    echo "./s76-t20.sh <YYYYMMDD> <modelname> <testnum>"
    exit
fi

sleep 270 && gnome-terminal --title=Short-Idle -- bash -c "julia 9801-logger.jl -g -p 10 -o '${PREFIX}_ShortIdle.csv'" && sleep 960 && gnome-terminal --title=Long-Idle -- bash -c "julia 9801-logger.jl -g -p 10 -o '${PREFIX}_LongIdle.csv'" && sleep 660 && julia 9801-logger.jl -g -p 10 -o "${PREFIX}_Suspend.csv" && julia 9801-logger.jl -g -p 10 -o "${PREFIX}_Off.csv"

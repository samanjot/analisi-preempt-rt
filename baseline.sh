#! /bin/bash

DIR="baseline/$1"
mkdir -p $DIR

echo "Running baseline linear membench"
../../membench/membench > $DIR/baseline.txt
sleep 10s

echo "Running baseline random membench"
../../membench/membench -r > $DIR/baseline_random.txt
sleep 10s



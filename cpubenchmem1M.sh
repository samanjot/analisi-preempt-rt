#! /usr/bin/env bash
sysctl -w kernel.sched_rt_runtime_us=-1

DIR=cpubench1M/$1

echo "Running cpubench"
mkdir -p $DIR

for cores in {1..5}
do
    echo "Running with $cores interference core(s)"
    
    # Start dedicated meminterf process on each interference core
    for core in $(seq 1 $cores)
    do
    	sudo taskset -c $core ../../membench/meminterf -v --size=156 --iterations=6000 --test=memcpy & 
    done
        
    sleep 1
        
    # Run benchmark on core 0
    sudo stress-ng --timer 1 --taskset=0 --timer-freq 1000000 --timer-slack 0 --timeout 300 --metrics-brief --times -q & 
    sudo cyclictest -a 0 -p 99 -m -i 1000 -D300 -h 10000 --json=$DIR/cyclic_stress_${cores}cores.json -q &
    wait $!
    echo "done with $cores cores"
        
    # Cleanup all meminterf processes
    sudo killall -9 meminterf
    wait
done
#! /bin/bash


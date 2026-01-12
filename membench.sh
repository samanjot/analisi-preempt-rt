#! /usr/bin/env bash
sysctl -w kernel.sched_rt_runtime_us=-1

DIR=membench/$1

echo "Running membench"
mkdir -p $DIR

for cores in {1..5}
do
    echo "Running with $cores interference core(s)"
    
    # Start dedicated meminterf process on each interference core
    for core in $(seq 1 $cores)
    do
    	sudo taskset -c $core ../../membench/meminterf -v --size=156 --iterations=3000 --test=memcpy & 
    done
        
    sleep 1
        
    # Run benchmark on core 0
    sudo taskset -c 0 ../../membench/membench | grep HESOCMARK > $DIR/t1-CPU0_interference_${cores}cores.txt & PID_TO_WAIT=$!
    wait $PID_TO_WAIT
    echo "done with $cores cores"
        
    # Cleanup all meminterf processes
    sudo killall -9 meminterf
    wait
done

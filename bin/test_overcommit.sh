#!/bin/bash
LOG_FILE=overcommit_memory.log

#TODO Use free
(( MEMORY_SIZE = 600 * 1024 * 1024 * 1024))
FREE_MEMORY=$(vmstat  -s -S K | grep free)

java -Dmemory.cosumption=static -Dmemory.size=$MEMORY_SIZE -jar MemoryTest.jar
IGNITE_PID=$!


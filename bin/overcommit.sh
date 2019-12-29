#!/usr/bin/env bash

IGNITE_HOME=$(realpath "$(dirname "$0")"/..)

ERR_FILE="$IGNITE_HOME"/overcommit.sh.err
LOG_FILE="$IGNITE_HOME"/overcommit.sh.log

exec > >(tee -ia "$LOG_FILE")
exec 2>>"$ERR_FILE"

# shellcheck source=bin/include/functions.sh
. "$IGNITE_HOME/bin/include/functions.sh"

estimate_heap

check_java

check_stress_ng

JVM_OPTS="-DIGNITE_HOME=$IGNITE_HOME -server ${HEAP_PARAMS} -XX:+AlwaysPreTouch -XX:+UseG1GC -XX:+ScavengeBeforeFullGC -XX:+DisableExplicitGC"

GREEDY_JAR="$IGNITE_HOME/lib/greedy-ignite-0.0.1-SNAPSHOT.jar"

OVERCOMMIT_MEMORY=$(cat /proc/sys/vm/overcommit_memory)
OVERCOMMIT_RATIO=$(cat /proc/sys/vm/overcommit_ratio)
SWAPINESS=$(cat /proc/sys/vm/swappiness)
SWAP=$(free | grep -i swap | awk '{ print $2 }')

echo -e "\n+-------------------------------------------------------+"
echo -e "|\t***** Starting overcommit-test: *****\t\t|\n|\t\t\t\t\t\t\t|"
echo -e "| Date:\t\t\t$(date '+%F %T')\t\t|"
echo -e "| vm.overcommit_memory:\t$OVERCOMMIT_MEMORY\t\t\t\t|"
echo -e "| vm.overcommit_ratio:\t$OVERCOMMIT_RATIO\t\t\t\t|"
echo -e "| vm.swappiness:\t$SWAPINESS\t\t\t\t|"
echo -e "| Total swap size:\t$SWAP\t\t\t\t|"
echo -e "+-------------------------------------------------------+\n"

#CSV_FILE="$IGNITE_HOME/overcommit-om_$OVERCOMMIT_MEMORY-or_$OVERCOMMIT_RATIO-sws_$SWAPINESS-swp_$SWAP.csv"
CSV_FILE="$IGNITE_HOME/overcommit.csv"

if ! [ -f "$CSV_FILE" ]; then
  echo "Overcommit memory;Overcommit Ratio;Swapiness; Swap;Test name;Iteration started;Iteration finished;Iteration duration;Instance name;Survived;Instance started;Instance PID;Command line" >>"$CSV_FILE"
fi

trap kill_handler SIGINT SIGTERM

ITERS_CNT=2
ITER_TIMEOUT=60

INSTANCE_DELAY=1
VMSTAT_DELAY=3

test_instances "LAZY_90" "$(lazy_instance 90)" "LAZY_90"

test_instances "GREEDY_90" "$(greedy_instance 90)" "GREEDY_90"

test_instances "LAZY_150" "$(lazy_instance 150)" "LAZY_150"

test_instances "GREEDY_150" "$(greedy_instance 150)" "GREEDY_150"

test_instances "LAZY_THEN_GREEDY" "$(lazy_instance 90 10)" "$(greedy_instance 90)" "LAZY_90_10" "GREEDY_90"

test_instances "LAZY_THEN_STRESS" "$(lazy_instance 90)" "$(stress_instance 90)" "LAZY_90" "STRESS_90"

test_instances "GREEDY_THEN_STRESS" "$(greedy_instance 90)" "$(stress_instance 90)" "GREEDY_90" "STRESS_90"

test_instances "STRESS_THEN_GREEDY" "$(stress_instance 90)" "$(greedy_instance 90)" "STRESS_90" "GREEDY_90"

echo -e "\n+-------------------------------------------------------+"
echo -e "|\t*** Overcommit-test succesfully finished: ***\t|\n|\t\t\t\t\t\t\t|"
echo -e "|\t\tDate: $(date '+%F %T')\t\t|"
echo -e "+-------------------------------------------------------+\n"

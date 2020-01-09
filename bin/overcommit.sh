#!/usr/bin/env bash

# TODO add vm.oom_dump_tasks

# Set IGNITE_HOME as directory higher to one level relatively to script directory
IGNITE_HOME=$(realpath "$(dirname "$0")"/..)

# Set up logs dir (create if not exists)
LOGS_DIR="${IGNITE_HOME}/logs"
if [ ! -d "$LOGS_DIR" ]; then
  mkdir "$LOGS_DIR"
fi

# Separate logs for stdout and stderr
ERR_FILE="$LOGS_DIR"/overcommit.err.log
LOG_FILE="$LOGS_DIR"/overcommit.log

# CSV file for automatic reports
CSV_FILE="$IGNITE_HOME/overcommit.csv"

# shellcheck source=bin/include/functions.sh
. "$IGNITE_HOME/bin/include/functions.sh"

# Estimate heap size depending on free memory size
estimate_heap

# Check JAVA and STRESS-NG presense
check_java
check_stress_ng

# Process passed options
process_options "$@"

# Save stdout output both to log and stdout, redirect stderr to err.log
exec > >(tee -ia "$LOG_FILE")
exec 2>>"$ERR_FILE"

# Set JVM options and Greedy-Ignite JAR-file path
JVM_OPTS="-DIGNITE_HOME=$IGNITE_HOME -server ${HEAP_PARAMS} -XX:+AlwaysPreTouch -XX:+UseG1GC -XX:+ScavengeBeforeFullGC -XX:+DisableExplicitGC"
GREEDY_JAR="$IGNITE_HOME/lib/greedy-ignite-0.0.1-SNAPSHOT.jar"

# Get overcommit memory parameters and swap parameters
OVERCOMMIT_MEMORY=$(cat /proc/sys/vm/overcommit_memory)
OVERCOMMIT_RATIO=$(cat /proc/sys/vm/overcommit_ratio)
OOM_KILL_ALLOCATING_TASK=$(cat /proc/sys/vm/oom_kill_allocating_task)
SWAPINESS=$(cat /proc/sys/vm/swappiness)
SWAP=$(free | grep -i swap | awk '{ print $2 }')

echo -e "\n+-------------------------------------------------------+"
echo -e "|\t***** Starting overcommit-test: *****\t\t|\n|\t\t\t\t\t\t\t|"
echo -e "| Date:\t\t\t\t$(date '+%F %T')\t|"
echo -e "| vm.overcommit_memory:\t\t$OVERCOMMIT_MEMORY\t\t\t|"
echo -e "| vm.overcommit_ratio:\t\t$OVERCOMMIT_RATIO\t\t\t|"
echo -e "| vm.oom_kill_allocating_task:\t$OOM_KILL_ALLOCATING_TASK\t\t\t|"
echo -e "| vm.swappiness:\t\t$SWAPINESS\t\t\t|"
echo -e "| Total swap size:\t\t$SWAP\t\t\t|"
echo -e "+-------------------------------------------------------+\n"

# Write header into CSV file in case if it not exists
if ! [ -f "$CSV_FILE" ]; then
  echo "vm.overcommit_memory;vm.overcommit_ratio;vm.oom_kill_allocating_task;vm.swappiness;Swap size;Test name;Iteration started;Iteration finished;Iteration duration;Instance name;Survived;Die cause;Instance started;Instance PID;Command line" >>"$CSV_FILE"
fi

# Set kill handler in case of script interruption (killing childs)
trap kill_handler SIGINT SIGTERM

test_instances "LAZY_80" "$(lazy_instance 80)" "LAZY_80"

test_instances "GREEDY_80" "$(greedy_instance 80)" "GREEDY_80"

test_instances "LAZY_150" "$(lazy_instance 150)" "LAZY_150"

test_instances "GREEDY_150" "$(greedy_instance 150)" "GREEDY_150"

test_instances "VERY_LAZY_THEN_GREEDY" "$(lazy_instance 80 10)" "$(greedy_instance 80)" "LAZY_80_10" "GREEDY_80"

test_instances "LAZY_THEN_GREEDY" "$(lazy_instance 80)" "$(greedy_instance 80)" "LAZY_80" "GREEDY_80"

test_instances "VERY_LAZY_THEN_STRESS" "$(lazy_instance 80 10)" "$(stress_instance 80)" "LAZY_80_10" "STRESS_80"

test_instances "LAZY_THEN_STRESS" "$(lazy_instance 80)" "$(stress_instance 80)" "LAZY_80" "STRESS_80"

test_instances "GREEDY_THEN_STRESS" "$(greedy_instance 80)" "$(stress_instance 80)" "GREEDY_80" "STRESS_80"

test_instances "STRESS_THEN_GREEDY" "$(stress_instance 80)" "$(greedy_instance 80)" "STRESS_80" "GREEDY_80"

echo -e "\n+-------------------------------------------------------+"
echo -e "|\t*** Overcommit-test succesfully finished: ***\t|\n|\t\t\t\t\t\t\t|"
echo -e "|\t\tDate: $(date '+%F %T')\t\t|"
echo -e "+-------------------------------------------------------+\n"

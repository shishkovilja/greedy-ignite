#!/usr/bin/env bash

IGNITE_HOME=$(realpath "$(dirname "$0")"/..)

ERR_FILE="$IGNITE_HOME"/overcommit.sh.err
LOG_FILE="$IGNITE_HOME"/overcommit.sh.log

exec > >(tee -ia "$LOG_FILE")
exec 2>>"$ERR_FILE"

# shellcheck source=bin/include/functions.sh
. "$IGNITE_HOME/bin/include/functions.sh"

check_java

check_stress_ng

JVM_OPTS="-DIGNITE_HOME=$IGNITE_HOME -server -Xms256m -Xmx256m -XX:+AlwaysPreTouch -XX:+UseG1GC -XX:+ScavengeBeforeFullGC -XX:+DisableExplicitGC"

GREEDY_PROPS="$JVM_OPTS"
LAZY_PROPS="-Dlaziness=5.0 $JVM_OPTS"

GREEDY_JAR="$IGNITE_HOME/lib/greedy-ignite-0.0.1-SNAPSHOT.jar"

LAZY_EXEC="$LAZY_PROPS $JVM_OPTS -jar $GREEDY_JAR"
GREEDY_EXEC="$GREEDY_PROPS $JVM_OPTS -jar $GREEDY_JAR"

STRESS_EXEC="$STRESS --vm 1 --vm-bytes"

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
  echo "Overcommit memory;Overcommit Ratio;Swapiness; Swap;Test name;Iteration started;Iteration finished;Iteration duration;Instance name;Survived;Instance PID;Command line;Instance started" >>"$CSV_FILE"
fi

ITERS_CNT=5
ITER_TIMEOUT=60

trap kill_handler SIGINT SIGTERM

test_lazy 90

test_greedy 90

test_lazy 120

test_greedy 120

lazy_then_greedy 70 70

lazy_then_stress 70 70

greedy_then_stress 70 70

stress_then_greedy 80 80

echo -e "\n+-------------------------------------------------------+"
echo -e   "|\t*** Overcommit-test succesfully finished: ***\t|\n|\t\t\t\t\t\t\t|"
echo -e   "|\t\tDate: $(date '+%F %T')\t\t|"
echo -e   "+-------------------------------------------------------+\n"

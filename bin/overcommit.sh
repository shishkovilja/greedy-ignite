#!/usr/bin/env bash

IGNITE_HOME=$(realpath "$(dirname "$0")"/..)

ERR_FILE="$IGNITE_HOME"/overcommit.sh.err
LOG_FILE="$IGNITE_HOME"/overcommit.sh.log

exec > >(tee -ia "$LOG_FILE")
exec 2>>"$ERR_FILE"

JAVA=$(type -p java)
RETCODE=$?

if [ $RETCODE -ne 0 ]; then
  echo "ERROR: no java found is system. Set up variable properly." 1>&2
  exit 1
fi

# shellcheck source=bin/include/functions.sh
. "$IGNITE_HOME/bin/include/functions.sh"
trap kill_handler SIGINT SIGTERM

JVM_OPTS="-DIGNITE_HOME=$IGNITE_HOME -server -Xms256m -Xmx256m -XX:+AlwaysPreTouch -XX:+UseG1GC -XX:+ScavengeBeforeFullGC -XX:+DisableExplicitGC"
GREEDY_JAR="$IGNITE_HOME/lib/greedy-ignite-0.0.1-SNAPSHOT.jar"

LAZY_PROPS="-Deat.ratio=70.0 -Dlaziness=5.0"
EAGER_PROPS="-Deat.ratio=70.0"

LAZY_EXEC="$JAVA $LAZY_PROPS $JVM_OPTS -jar $GREEDY_JAR"
GREEDY_EXEC="$JAVA $EAGER_PROPS $JVM_OPTS -jar $GREEDY_JAR"

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

CSV_FILE="$IGNITE_HOME/overcommit-om_$OVERCOMMIT_MEMORY-or_$OVERCOMMIT_RATIO-sws_$SWAPINESS-swp_$SWAP.csv"
echo "Test name;Iteration started;Iteration finished;Iteration duration;Instance name;Survived;Instance PID;Command line;Instance started" >>"$CSV_FILE"

lazy_then_greedy "$LAZY_EXEC" "$GREEDY_EXEC" 5

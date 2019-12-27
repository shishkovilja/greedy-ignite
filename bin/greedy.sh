#!/usr/bin/env bash

IGNITE_HOME=$(realpath "$(dirname "$0")"/..)

ERR_FILE="$IGNITE_HOME"/greedy.sh.err
LOG_FILE="$IGNITE_HOME"/greedy.sh.log

JVM_OPTS="$*"

if [ -z "$JVM_OPTS" ]; then
  echo -e "\nEat size should be set via JVM options: with eat.size, eat.ratio or over.eat.size, eg.

    	$0 -Deat.ratio=70.0 -Dlaziness=3.0\n"
  exit 2
fi

exec > >(tee -ia "$LOG_FILE")
exec 2>>"$ERR_FILE"

JVM_OPTS="$JVM_OPTS -DIGNITE_HOME=$IGNITE_HOME -server -Xms256m -Xmx256m -XX:+AlwaysPreTouch -XX:+UseG1GC -XX:+ScavengeBeforeFullGC -XX:+DisableExplicitGC"

echo -e "\n+-------------------------------------------------------+"
echo -e   "|\t***** Starting greedy-ignite: *****\t\t|\n|\t\t\t\t\t\t\t|"
echo -e   "| Date:\t\t\t$(date '+%F %T')\t\t|"
echo -e   "| vm.overcommit_memory:\t$(cat /proc/sys/vm/overcommit_memory)\t\t\t\t|"
echo -e   "| vm.overcommit_ratio:\t$(cat /proc/sys/vm/overcommit_ratio)\t\t\t\t|"
echo -e   "| vm.swappiness:\t$(cat /proc/sys/vm/swappiness)\t\t\t\t|"
echo -e   "| Total swap size:\t$(free | grep -i swap | awk '{ print $2 }')\t\t\t\t|"
echo -e   "+-------------------------------------------------------+\n"

WORK_DIR=$IGNITE_HOME/work
if ! [ -d "$WORK_DIR" ]; then
  mkdir "$WORK_DIR"
fi

java $JVM_OPTS -jar "$IGNITE_HOME"/lib/greedy-ignite-0.0.1-SNAPSHOT.jar >/dev/null &

PID=$!
echo -e "$(date '+[%F %T]') Greedy-Ingite started:\t[PID: $PID]"
echo -e "$(date '+[%F %T]') Script opts: $*"
echo -e "$(date '+[%F %T]') JVM opts: $JVM_OPTS"

wait

echo -e "$(date '+[%F %T]') Greedy-Ignite finished:\t[PID: $PID]\n"

#!/usr/bin/env bash
IGNITE_HOME=$(dirname "$(dirname "$0")")

#echo $(env | grep IGNITE_HOME)

JVM_OPTS="$*"

if [ -z "$JVM_OPTS" ]; then
    echo -e "\nEat size should be set via JVM options: with eat.size, eat.ratio or over.eat.size, eg.

    	$0 -Deat.ratio=70.0 -Dlaziness=3.0\n" >&2
    exit 2
fi

JVM_OPTS="$JVM_OPTS -DIGNITE_HOME=$IGNITE_HOME -server -Xms256m -Xmx256m -XX:+AlwaysPreTouch -XX:+UseG1GC -XX:+ScavengeBeforeFullGC -XX:+DisableExplicitGC"

#echo $JVM_OPTS

echo -e "\n+-------------------------------------------------------+"
echo -e   "|\t***** Starting greedy-ignite: *****\t\t|\n|\t\t\t\t\t\t\t|"
echo -e   "| Date:\t\t\t$(date)\t|"
echo -e   "| vm.overcommit_memory:\t$(cat /proc/sys/vm/overcommit_memory)\t\t\t\t|"
echo -e   "| vm.overcommit_ratio:\t$(cat /proc/sys/vm/overcommit_ratio)\t\t\t\t|"
echo -e   "| vm.swappiness:\t$(cat /proc/sys/vm/swappiness)\t\t\t\t|"
echo -e   "| Total swap size:\t$(free | grep -i swap | awk '{ print $2 }')\t\t\t\t|"
echo -e "+-------------------------------------------------------+\n"

WORK_DIR=$IGNITE_HOME/work
if ! [ -d "$WORK_DIR" ]; then
    mkdir "$WORK_DIR"
fi

java $JVM_OPTS -jar "$IGNITE_HOME"/lib/greedy-ignite-0.0.1-SNAPSHOT.jar > /dev/null 2> "$IGNITE_HOME"/overcommit.sh.err &

PID=$!
echo -e "PID of greedy-ingite:\n$PID"

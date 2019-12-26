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

JVM_OPTS="-DIGNITE_HOME=$IGNITE_HOME -server -Xms256m -Xmx256m -XX:+AlwaysPreTouch -XX:+UseG1GC -XX:+ScavengeBeforeFullGC -XX:+DisableExplicitGC"
GREEDY_JAR="$IGNITE_HOME/lib/greedy-ignite-0.0.1-SNAPSHOT.jar"

LAZY_PROPS="-Deat.ratio=70.0 -Dlaziness=5.0"
EAGER_PROPS="-Deat.ratio=70.0"

LAZY="$JAVA $LAZY_PROPS $JVM_OPTS -jar $GREEDY_JAR"
EAGER="$JAVA $EAGER_PROPS $JVM_OPTS -jar $GREEDY_JAR"

echo -e "\n+-------------------------------------------------------+"
echo -e "|\t***** Starting overcommit-test: *****\t\t|\n|\t\t\t\t\t\t\t|"
echo -e "| Date:\t\t\t$(date '+%F %T')\t\t|"
echo -e "| vm.overcommit_memory:\t$(cat /proc/sys/vm/overcommit_memory)\t\t\t\t|"
echo -e "| vm.overcommit_ratio:\t$(cat /proc/sys/vm/overcommit_ratio)\t\t\t\t|"
echo -e "| vm.swappiness:\t$(cat /proc/sys/vm/swappiness)\t\t\t\t|"
echo -e "| Total swap size:\t$(free | grep -i swap | awk '{ print $2 }')\t\t\t\t|"
echo -e "+-------------------------------------------------------+\n"

VM_WAIT=2
VM_ITER=5
ITER_TIMEOUT=60

for i in {1..5}; do
  echo -e "$(date '+[%F %T]') Started test: first LAZY and then EAGER:\t[iteration #$i]"

  $LAZY >/dev/null &
  LAZY_PID=$!
  echo "$(date '+[%F %T]') LAZY started: [PID: $LAZY_PID]"

  sleep 2

  $EAGER >/dev/null &
  EAGER_PID=$!
  echo "$(date '+[%F %T]') EAGER started: [PID: $EAGER_PID]"

  DURATION=0
  while [ $(ps "$LAZY_PID" "$EAGER_PID" | wc -l) -gt 2 ]; do
    vmstat -w -S m -t $VM_WAIT $VM_ITER

    ((DURATION += VM_WAIT * VM_ITER))

    if [ $DURATION -gt $ITER_TIMEOUT ]; then
      echo "$(date '+[%F %T]') BOTH survived during timeout. Killing and perform next iteration..."
      kill $EAGER_PID
      kill $LAZY_PID
      wait
      break
    fi
  done

  if [ $DURATION -gt $ITER_TIMEOUT ]; then
    continue
  fi

  if [[ $(ps "$EAGER_PID" | wc -l) -eq 2 ]]; then
    echo "$(date '+[%F %T]') EAGER survived. Continue to new iteration..."
    SURVIVED=$EAGER_PID
  elif [[ $(ps "$LAZY_PID" | wc -l) -eq 2 ]]; then
    echo "$(date '+[%F %T]') LAZY survived. Continue to new iteration..."
    SURVIVED=$LAZY_PID
  else
    echo "$(date '+[%F %T]') LAZY and GREEDY PIDs count ERROR. Terminating..."
    kill -9 $EAGER_PID
    kill -9 $LAZY_PID
    exit 10
  fi

  kill "$SURVIVED"
  wait
done

echo -e "$(date '+[%F %T]') Finished all tests: first LAZY and then EAGER"

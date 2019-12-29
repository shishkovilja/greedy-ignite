#!/usr/bin/env bash

# PIDS array
PIDS=()

kill_handler() {
  log "Unexpected script termination. Killing child processes..."

  for PID in "${PIDS[@]}"; do
    log "Killing [PID: $PID]"

    kill "$PID"
  done

  kill "$VMSTAT_PID"

  wait "${PIDS[@]}" "$VMSTAT_PID"

  log "Child processes killed. Exiting."

  exit 2
}

function log() {
  echo -e "$(date '+[%F %T]') $1"
}

function start_iter() {
  PIDS=()

  for ((j = 0; j < INSTANCES_AMOUNT; j++)); do
    ${INSTANCES[$j]} >/dev/null &

    local PID=$!
    PIDS+=("$PID")

    INSTANCES_STARTS+=("$(date '+%F %T')")
    log ">>>>>> ${INSTANCES_NAMES[$j]} started: [PID: $PID]"

    sleep "$INSTANCE_DELAY"
  done

  local VMSTAT_CNT
  ((VMSTAT_CNT = ITER_TIMEOUT / VMSTAT_DELAY + 1))

  vmstat -w -S m -t "$VMSTAT_DELAY" "$VMSTAT_CNT" &
  VMSTAT_PID=$!

  ITER_DURATION=0
  while ((ITER_DURATION <= ITER_TIMEOUT && $(ps --no-headers "${PIDS[@]}" | wc -l) == INSTANCES_AMOUNT)); do
    sleep 1
    ((ITER_DURATION++))
  done

  if [ $ITER_DURATION -lt "$ITER_TIMEOUT" ]; then
    PIDS+=("$VMSTAT_PID")
  fi
}

function write_csv() {
  local IDX="$1"
  local SURVIVED="$2"
  #                 "Overcommit memory;Overcommit Ratio;Swapiness; Swap;Test name;Iteration started;Iteration finished;Iteration duration;Instance name;Survived;Instance started;Instance PID;Command line"

  local COMMON_INFO="$OVERCOMMIT_MEMORY;$OVERCOMMIT_RATIO;$SWAPINESS;$SWAP;$TEST_NAME;$ITERATION_STARTED;$ITERATION_FINISHED;$ITER_DURATION"

  #                    Instance name;Survived;Instance started;Instance PID;Command line
  echo "$COMMON_INFO;${INSTANCES_NAMES[$IDX]};$SURVIVED;${INSTANCES_STARTS[$IDX]};${PIDS[$IDX]};${INSTANCES[IDX]}" >>"$CSV_FILE"
}

function finish_iter() {
  for ((j = 0; j < INSTANCES_AMOUNT; j++)); do
    if [ -n "$(ps --no-headers "${PIDS[$j]}")" ]; then
      log ">>>>>> [${INSTANCES_NAMES[$j]}, ${PIDS[$j]}] - [SURVIVED]"
      write_csv $j "TRUE"
    else
      log ">>>>>> [${INSTANCES_NAMES[$j]}, ${PIDS[$j]}] - [DIED]"
      write_csv $j "FALSE"
    fi
  done

  log ">>>>>> Killing child processes and waiting for them to finish"

  kill "${PIDS[@]}"
  wait "${PIDS[@]}"

  PIDS=()
}

function test_instances() {
  PARAMS=("$@")

  local TEST_NAME=${PARAMS[0]}

  local REMAINDER
  ((REMAINDER = $# % 2))
  if [ "$REMAINDER" -eq 0 ]; then
    log "WARNING: Test [$TEST_NAME] was skipped, because it has wrong arguments:\n\t$*"
    return
  fi

  local INSTANCES_AMOUNT
  ((INSTANCES_AMOUNT = ($# - 1) / 2))

  log "> Starting test: $TEST_NAME"
  log ">>> Pending instances:"

  INSTANCES=()
  INSTANCES_NAMES=()
  for ((i = 1; i <= INSTANCES_AMOUNT; i++)); do
    INSTANCES+=("${PARAMS[$i]}")
    INSTANCES_NAMES+=("${PARAMS[INSTANCES_AMOUNT + $i]}")

    log ">>>>>> [$i]: ${INSTANCES_NAMES[$i - 1]}\t${INSTANCES[$i - 1]}"
  done

  echo ""

  for ((i = 1; i <= ITERS_CNT; i++)); do
    # Variables for CSV report
    local ITERATION_STARTED
    local ITERATION_FINISHED
    local ITER_DURATION
    local INSTANCES_STARTS=()

    ITERATION_STARTED="$(date '+%F %T')"
    log ">>> Started iteration: $TEST_NAME: [Number: $i]"

    start_iter

    ITERATION_FINISHED="$(date '+%F %T')"

    log ">>> Some instance died or timeout occurs. Finishing iteration..."
    log ">>> Instances running during: ${ITER_DURATION} seconds"

    finish_iter

    log ">>> Finished iteration: $TEST_NAME: [Number: $i]\n"
  done

  log "> Finished test: $TEST_NAME\n"
}

function lazy_instance() {
  local LAZY_PROP="-Dlaziness="
  if [ -n "$2" ]; then
    LAZY_PROP="${LAZY_PROP}$2"
  else
    LAZY_PROP="${LAZY_PROP}5.0"
  fi

  echo "$JAVA -Deat.ratio=$1 $LAZY_PROP $JVM_OPTS -jar $GREEDY_JAR"
}

function greedy_instance() {
  echo "$JAVA -Deat.ratio=$1 $JVM_OPTS -jar $GREEDY_JAR"
}

function stress_instance() {
  echo "$STRESS --vm 1 --vm-bytes $1%"
}

function check_java() {
  JAVA=$(type -p java)
  RETCODE=$?

  if [ $RETCODE -ne 0 ]; then
    log "ERROR: no JAVA found is system. Set up java properly." 1>&2
    exit 1
  fi
}

function check_stress_ng() {
  STRESS=$(type -p stress-ng)
  RETCODE=$?

  if [ $RETCODE -ne 0 ]; then
    log "ERROR: no STRESS-NG in system. Install it properly." 1>&2
    exit 1
  fi
}

function estimate_heap() {
  FREE_GBYTES=$(free -g | grep -i "mem:" | awk '{ print $4 }')

  if [ -z "$FREE_GBYTES" ]; then
    log "ERROR: free memory size is empty"
    exit 3
  fi

  if [ "$FREE_GBYTES" -lt 2 ]; then
    HEAP_PARAMS="-Xms128m -Xmx128m"
  elif [ "$FREE_GBYTES" -lt 4 ]; then
    HEAP_PARAMS="-Xms256m -Xmx256m"
  elif [ "$FREE_GBYTES" -lt 8 ]; then
    HEAP_PARAMS="-Xms512m -Xmx512m"
  elif [ "$FREE_GBYTES" -lt 16 ]; then
    HEAP_PARAMS="-Xms1g -Xmx1g"
  elif [ "$FREE_GBYTES" -lt 32 ]; then
    HEAP_PARAMS="-Xms2g -Xmx2g"
  elif [ "$FREE_GBYTES" -lt 128 ]; then
    HEAP_PARAMS="-Xms8g -Xmx8g"
  else
    HEAP_PARAMS="-Xms16g -Xmx16g"
  fi
}

#!/usr/bin/env bash

# PIDS array
PIDS=()

# TODO STRESS_NG childs PIDS checking out
# Start iteration
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

  #Delay, 'waiting' for release of memory
  sleep 2

  if [ $ITER_DURATION -lt "$ITER_TIMEOUT" ]; then
    PIDS+=("$VMSTAT_PID")
  fi
}

# Write results to CSV
function write_csv() {
  local IDX="$1"
  local SURVIVED="$2"
  #                 "Overcommit memory;Overcommit Ratio;Swapiness; Swap;Test name;Iteration started;Iteration finished;Iteration duration;Instance name;Survived;Instance started;Instance PID;Command line"

  local COMMON_INFO="$OVERCOMMIT_MEMORY;$OVERCOMMIT_RATIO;$SWAPINESS;$SWAP;$TEST_NAME;$ITERATION_STARTED;$ITERATION_FINISHED;$ITER_DURATION"

  #                    Instance name;Survived;Instance started;Instance PID;Command line
  echo "$COMMON_INFO;${INSTANCES_NAMES[$IDX]};$SURVIVED;${INSTANCES_STARTS[$IDX]};${PIDS[$IDX]};${INSTANCES[IDX]}" >>"$CSV_FILE"
}

# Finish iteration
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

# Test instances, first parameter - test name, then instances exec strings should be passed, then instance names should be passed
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

# Get lazy instance exec string, first parameter - eat.ratio, second - laziness
function lazy_instance() {
  local LAZY_PROP="-Dlaziness="
  if [ -n "$2" ]; then
    LAZY_PROP="${LAZY_PROP}$2"
  else
    LAZY_PROP="${LAZY_PROP}3.0"
  fi

  echo "$JAVA -Deat.ratio=$1 $LAZY_PROP $JVM_OPTS -jar $GREEDY_JAR"
}

# Get greedy instance exec string, first parameter - eat.ratio
function greedy_instance() {
  echo "$JAVA -Deat.ratio=$1 $JVM_OPTS -jar $GREEDY_JAR"
}

# Get greedy instance exec string, first parameter - vm-bytes value in percent
function stress_instance() {
  echo "$STRESS --oomable --vm 1 --vm-bytes $1%"
}

# Check and set path to JAVA
function check_java() {
  JAVA=$(type -p java)
  RETCODE=$?

  if [ $RETCODE -ne 0 ]; then
    log "ERROR: no JAVA found is system. Set up java properly." 1>&2
    exit 1
  fi
}

# Check and set path to STRESS-NG
function check_stress_ng() {
  STRESS=$(type -p stress-ng)
  RETCODE=$?

  if [ $RETCODE -ne 0 ]; then
    log "ERROR: no STRESS-NG in system. Install it properly." 1>&2
    exit 1
  fi
}

# Get heap size JVM parameters depending on free memory
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

# Kill handler, kills child processes
function kill_handler() {
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

# Log message with date
function log() {
  echo -e "$(date '+[%F %T]') $1"
}

#Check that argument is valid int
function check_int_arg() {
  if [[ "$1" =~ ^[0-9]+$ ]]; then
    RETVAL="$1"
  else
    log "Incorrect value '$1' for argument '$2' - should be valid integer" 1>&2

    exit 16
  fi
}

# Process passed options
function process_options() {
  # Set default settings for test iterations
  ITERS_CNT=1
  ITER_TIMEOUT=60
  INSTANCE_DELAY=1
  VMSTAT_DELAY=3

  if [ -n "$*" ]; then
    while getopts ":c:t:d:V:" OPT; do
      case $OPT in
      c)
        check_int_arg "$OPTARG" "ITERS_CNT"
        ITERS_CNT=$RETVAL
        ;;
      t)
        check_int_arg "$OPTARG" "ITER_TIMEOUT"
        ITER_TIMEOUT=$RETVAL
        ;;
      d)
        check_int_arg "$OPTARG" "INSTANCE_DELAY"
        INSTANCE_DELAY=$RETVAL
        ;;
      V)
        check_int_arg "$OPTARG" "VMSTAT_DELAY"
        VMSTAT_DELAY=$RETVAL
        ;;
      *)
        log "Incorrect parameters usage:
        $(basename "$0") [-c ITERS_CNT] [-t ITER_TIMEOUT] [-t INSTANCE_DELAY] [-V VMSTAT_DELAY]
            ITERS_CNT - number of iterations, performed for tests
            ITER_TIMEOUT - iteration timeout, after reaching it child processes will be killed
            INSTANCE_DELAY - delay between instances startup
            VMSTAT_DELAY - delay between vmstat outputs to stdout" 1>&2

        exit 15
        ;;
      esac
    done
  fi

  log "Set following iteration options: [ITERS_CNT=$ITERS_CNT, ITER_TIMEOUT=$ITER_TIMEOUT, INSTANCE_DELAY=$INSTANCE_DELAY, VMSTAT_DELAY=$VMSTAT_DELAY]"
}

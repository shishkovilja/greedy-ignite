#!/usr/bin/env bash

# PIDS array
PIDS=()

# Recursively add all childs of a given PID to PIDS array
function add_childs() {
  while read -r CHILD_PID; do
    if [ -n "$CHILD_PID" ]; then
      PROCS_STARTS+=("${PROCS_STARTS[$j]}")
      PROCS_NAMES+=("${INSTANCES_NAMES[$j]}_CHILD_OF_$1")
      PROCS_LOGS+=("${INSTANCES_LOGS[$j]}")
      PROCS_CMDS+=("")

      PIDS+=("$CHILD_PID")

      ((PROCS_CNT++))

      log ">>>>>>>>> ${INSTANCES_NAMES[$j]} child found: [PID: $CHILD_PID]"

      add_childs "$CHILD_PID"
    fi
  done <<<"$(pgrep -P "$1")"
}

# Start iteration
function start_iter() {
  PIDS=()

  for ((j = 0; j < INSTANCES_CNT; j++)); do
    INSTANCES_LOGS+=("${LOGS_DIR}/$(date '+%s')-${INSTANCES_NAMES[$j]}.log")
    ${INSTANCES[$j]} &>"${INSTANCES_LOGS[$j]}" &

    local PID=$!
    PIDS+=("$PID")

    PROCS_STARTS+=("$(date '+%F %T')")
    PROCS_NAMES+=("${INSTANCES_NAMES[$j]}")
    PROCS_CMDS+=("${INSTANCES[$j]}")
    PROCS_LOGS+=("${INSTANCES_LOGS[$j]}")

    ((PROCS_CNT++))

    log ">>>>>> ${INSTANCES_NAMES[$j]} started: [PID: $PID]"

    if ((j < INSTANCES_CNT - 1)); then
      sleep "$INSTANCE_DELAY"
    else
      sleep 0.5
    fi

    add_childs "$PID"
  done

  local VMSTAT_CNT
  ((VMSTAT_CNT = ITER_TIMEOUT / VMSTAT_DELAY + 1))

  vmstat -w -S m -t "$VMSTAT_DELAY" "$VMSTAT_CNT" &
  VMSTAT_PID=$!

  ITER_DURATION=0
  while ((ITER_DURATION <= ITER_TIMEOUT && $(ps --no-headers "${PIDS[@]}" | wc -l) == PROCS_CNT)); do
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
  #                 "vm.overcommit_memory;vm.overcommit_ratio;vm.oom_kill_allocating_task;vm.swappiness;Swap size;Test name;Iteration started;Iteration finished;Iteration duration;Instance name;Survived;Instance started;Instance PID;Command line"

  local COMMON_INFO="$OVERCOMMIT_MEMORY;$OVERCOMMIT_RATIO;$OOM_KILL_ALLOCATING_TASK;$SWAPINESS;$SWAP;$TEST_NAME;$ITERATION_STARTED;$ITERATION_FINISHED;$ITER_DURATION"

  #                    Instance name;Survived;Die cause;Instance started;Instance PID;Command line
  echo -e "$COMMON_INFO;${PROCS_NAMES[$IDX]};$SURVIVED;$LAST_DIE_CAUSE;${PROCS_STARTS[$IDX]};${PIDS[$IDX]};${PROCS_CMDS[$IDX]}" >>"$CSV_FILE"
}

# Instance logs parser
function parse_error() {
  local JOOME=$(tail -n50 "${PROCS_LOGS[$1]}" | grep "type=CRITICAL_ERROR, err=java.lang.OutOfMemoryError" | tail -n1)
  local STRESS_OOM=$(tail -n30 "${PROCS_LOGS[$1]}" | grep "${PIDS[$1]}.*no available memory")
  local LAST_LOG_RECORDS=$(tail -n5 "${PROCS_LOGS[$1]}")

  if [ -n "$JOOME" ]; then
    LAST_DIE_CAUSE=$JOOME
  elif [ -n "$STRESS_OOM" ]; then
    LAST_DIE_CAUSE=$STRESS_OOM
  else
    # TODO Remove excessive output for parent processes (parent killed both with child)

    LAST_DIE_CAUSE="No cause found in log, last 5 lines from it:\n$LAST_LOG_RECORDS"
  fi

  # TODO su/sudo check should be added
  local OOM_RECORD
  OOM_RECORD=$(sudo grep -i "out of memory.*${PIDS[$1]}" /var/log/messages)

  if [ -n "$OOM_RECORD" ]; then
    LAST_DIE_CAUSE="\"${LAST_DIE_CAUSE}\n\nOOM found:\n${OOM_RECORD}\""
  else
    LAST_DIE_CAUSE="\"${LAST_DIE_CAUSE}\""
  fi
}

# Finish iteration
function finish_iter() {
  local LAST_DIE_CAUSE

  for ((j = 0; j < PROCS_CNT; j++)); do
    LAST_DIE_CAUSE=""

    if [ -n "$(ps --no-headers "${PIDS[$j]}")" ]; then
      log ">>>>>> [${PROCS_NAMES[$j]}, ${PIDS[$j]}] - [SURVIVED]"
      write_csv $j "TRUE"
    else
      log ">>>>>> [${PROCS_NAMES[$j]}, ${PIDS[$j]}] - [DIED]"

      parse_error $j

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

  local INSTANCES_CNT
  ((INSTANCES_CNT = ($# - 1) / 2))

  log "> Starting test: $TEST_NAME"

  local INSTANCES=()
  local INSTANCES_NAMES=()
  local INSTANCES_LOGS=()

  log ">>> Pending instances:"
  for ((i = 1; i <= INSTANCES_CNT; i++)); do
    INSTANCES+=("${PARAMS[$i]}")
    INSTANCES_NAMES+=("${PARAMS[INSTANCES_CNT + $i]}")

    log ">>>>>> [$i]: ${INSTANCES_NAMES[$i - 1]}\t${INSTANCES[$i - 1]}"
  done

  echo ""

  for ((i = 1; i <= ITERS_CNT; i++)); do
    # Variables for CSV report
    local ITERATION_STARTED
    local ITERATION_FINISHED
    local ITER_DURATION

    local PROCS_CNT=0
    local PROCS_NAMES=()
    local PROCS_STARTS=()
    local PROCS_CMDS=()
    local PROCS_LOGS=()

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
        $(basename "$0") [-c ITERS_CNT] [-t ITER_TIMEOUT] [-d INSTANCE_DELAY] [-V VMSTAT_DELAY]
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

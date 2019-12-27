#!/usr/bin/env bash

#vmstat delay and count
VMSTAT_DELAY=2
VMSTAT_CNT=5

# PIDs variables
FIRST_PID=-1
SECOND_PID=-1
INSTANCE_PID=-1

kill_handler() {
  echo "$(date '+[%F %T]') Unexpected script termination. Killing child processes..."

  if [ "$FIRST_PID" -gt 0 ]; then
    echo "$(date '+[%F %T]') Killing [PID: $FIRST_PID]"
    kill "$FIRST_PID"
  fi

  if [ "$SECOND_PID" -gt 0 ]; then
    echo "$(date '+[%F %T]') Killing [PID: $SECOND_PID]"
    kill "$SECOND_PID"
  fi

  if [ "$INSTANCE_PID" -gt 0 ]; then
    echo "$(date '+[%F %T]') Killing [PID: $INSTANCE_PID]"
    kill "$INSTANCE_PID"
  fi

  wait

  echo "$(date '+[%F %T]') Child processes killed. Exiting."
  exit 2
}

wait_and_print_vmstat() {
  local DURATION=0

  while [ "$(ps --no-headers "$@" | wc -l)" -eq "$#" ]; do
    vmstat -w -S m -t "$VMSTAT_DELAY" "$VMSTAT_CNT"

    ((DURATION += VMSTAT_DELAY * VMSTAT_CNT))

    if [ $DURATION -gt "$ITER_TIMEOUT" ]; then
      echo "$(date '+[%F %T]') ALL survived during timeout. Killing and perform next iteration..."

      kill "$@"

      wait
      break
    fi
  done

  return $DURATION
}

write_csv_first_second() {
  local FIRST_SURVIVED="$1"
  local SECOND_SURVIVED="$2"
  #       "Overcommit memory;Overcommit Ratio;Swapiness; Swap;Test name;Iteration started;Iteration finished;Iteration duration;Instance name;Survived;Instance PID;Command line;Instance started"

  local COMMON_INFO="$OVERCOMMIT_MEMORY;$OVERCOMMIT_RATIO;$SWAPINESS;$SWAP;$TEST_NAME;$ITERATION_STARTED;$ITERATION_FINISHED;$ITERATION_DURATION"

  echo "$COMMON_INFO;$FIRST_NAME;$FIRST_SURVIVED;$FIRST_PID;$FIRST;$FIRST_STARTED" >>"$CSV_FILE"
  echo "$COMMON_INFO;$SECOND_NAME;$SECOND_SURVIVED;$SECOND_PID;$SECOND;$SECOND_STARTED" >>"$CSV_FILE"
}

first_then_second() {
  local FIRST="$1"
  local FIRST_NAME="$2"
  local SECOND="$3"
  local SECOND_NAME="$4"
  local TEST_NAME=$5

  for ((i = 1; i <= ITERS_CNT; i++)); do
    # Variables for CSV report
    local ITERATION_STARTED
    local FIRST_STARTED
    local SECOND_STARTED
    local ITERATION_FINISHED
    local ITERATION_DURATION

    ITERATION_STARTED="$(date '+%F %T')"
    echo -e "\n[$ITERATION_STARTED] Started iteration: firstly start $FIRST_NAME and then $SECOND_NAME:\t[iteration #$i]"

    $FIRST >/dev/null &
    FIRST_PID=$!
    FIRST_STARTED="$(date '+%F %T')"
    echo "[$FIRST_STARTED] $FIRST_NAME started: [PID: $FIRST_PID]"

    sleep 2

    $SECOND >/dev/null &
    SECOND_PID=$!
    SECOND_STARTED="$(date '+%F %T')"
    echo "[$SECOND_STARTED] $SECOND_NAME started: [PID: $SECOND_PID]"

    wait_and_print_vmstat $FIRST_PID $SECOND_PID
    ITERATION_DURATION="$?"

    ITERATION_FINISHED="$(date '+%F %T')"

    if [ $ITERATION_DURATION -gt "$ITER_TIMEOUT" ]; then
      write_csv_first_second "TRUE" "TRUE"

      continue
    fi

    local SURVIVED_PID=0
    if [[ $(ps --no-headers "$SECOND_PID" | wc -l) -eq 1 ]]; then
      echo "$(date '+[%F %T]') $SECOND_NAME survived. Continue to new iteration..."

      SURVIVED_PID=$SECOND_PID

      write_csv_first_second "FALSE" "TRUE"
    elif [[ $(ps --no-headers "$FIRST_PID" | wc -l) -eq 1 ]]; then
      echo "$(date '+[%F %T]') $FIRST_NAME survived. Continue to new iteration..."

      SURVIVED_PID=$FIRST_PID

      write_csv_first_second "TRUE" "FALSE"
    else
      echo "$(date '+[%F %T]') $FIRST_NAME and $SECOND_NAME PIDs count ERROR. Terminating..."

      kill -9 $SECOND_PID
      kill -9 $FIRST_PID

      exit 10
    fi

    kill "$SURVIVED_PID"

    wait

    FIRST_PID=-1
    SECOND_PID=-1
  done

  echo -e "$(date '+[%F %T]') Finished all iterations: first $FIRST_NAME and then $SECOND_NAME"
}

write_csv_one_instance() {
  local SURVIVED="$1"
  #       "Overcommit memory;Overcommit Ratio;Swapiness; Swap;Test name;Iteration started;Iteration finished;Iteration duration;Instance name;Survived;Instance PID;Command line;Instance started"

  local COMMON_INFO="$OVERCOMMIT_MEMORY;$OVERCOMMIT_RATIO;$SWAPINESS;$SWAP;$TEST_NAME;$ITERATION_STARTED;$ITERATION_FINISHED;$ITERATION_DURATION"

  echo "$COMMON_INFO;$INSTANCE_NAME;$SURVIVED;$INSTANCE_PID;$INSTANCE;" >>"$CSV_FILE"
}

test_one_instance() {
  local INSTANCE="$1"
  local INSTANCE_NAME="$2"
  local TEST_NAME=$INSTANCE_NAME

  for ((i = 1; i <= ITERS_CNT; i++)); do
    # Variables for CSV report
    local ITERATION_STARTED
    local ITERATION_FINISHED
    local ITERATION_DURATION

    ITERATION_STARTED="$(date '+%F %T')"
    echo -e "\n[$ITERATION_STARTED] Started iteration: $INSTANCE_NAME:\t[iteration #$i]"

    $INSTANCE >/dev/null &
    INSTANCE_PID=$!
    echo "[$(date '+%F %T')] $INSTANCE_NAME started: [PID: $INSTANCE_PID]"

    wait_and_print_vmstat $INSTANCE_PID
    ITERATION_DURATION="$?"

    ITERATION_FINISHED="$(date '+%F %T')"

    if [ $ITERATION_DURATION -gt "$ITER_TIMEOUT" ]; then
      echo "$(date '+[%F %T]') $INSTANCE_NAME [SURVIVED]. Continue to new iteration..."

      write_csv_one_instance "TRUE"

      kill "$INSTANCE_PID"

      wait
    else
      echo "$(date '+[%F %T]') $INSTANCE_NAME [DIED]. Continue to new iteration..."

      write_csv_one_instance "FALSE"
    fi

    INSTANCE_PID=-1
  done

  echo -e "$(date '+[%F %T]') Finished all iterations: $INSTANCE_NAME"
}

check_and_start() {
  if [[ $ITERS_CNT -gt 0 && $ITER_TIMEOUT -gt 0 ]]; then
    "$@"
  else
    echo "$(date '+[%F %T]') WARNING: Test skipped: ${*: -1}, incorrect options: [ITERS_CNT=$ITERS_CNT, ITER_TIMEOUT=$ITER_TIMEOUT]"
  fi
}

lazy_then_greedy() {
  LAZY_EXECX="$JAVA -Deat.ratio=$1 $LAZY_EXEC"

  GREEDY_EXECX="$JAVA -Deat.ratio=$2 $GREEDY_EXEC"

  check_and_start first_then_second "$LAZY_EXECX" "LAZY IGNITE" "$GREEDY_EXECX" "GREEDY IGNITE" "LAZY_THEN_GREEDY"
}

lazy_then_stress() {
  LAZY_EXECX="$JAVA -Deat.ratio=$1 $LAZY_EXEC"

  STRESS_EXECX="$STRESS_EXEC $2%"

  check_and_start first_then_second "$LAZY_EXECX" "LAZY IGNITE" "$STRESS_EXECX" "STRESS-NG" "LAZY_THEN_STRESS"
}

greedy_then_stress() {
  GREEDY_EXECX="$JAVA -Deat.ratio=$1 $GREEDY_EXEC"

  STRESS_EXECX="$STRESS_EXEC $2%"

  check_and_start first_then_second "$GREEDY_EXECX" "GREEDY IGNITE" "$STRESS_EXECX" "STRESS-NG" "GREEDY_THEN_STRESS"
}

stress_then_greedy() {
  STRESS_EXECX="$STRESS_EXEC $1%"

  GREEDY_EXECX="$JAVA -Deat.ratio=$2 $GREEDY_EXEC"

  check_and_start first_then_second "$STRESS_EXECX" "STRESS-NG" "$GREEDY_EXECX" "GREEDY IGNITE" "STRESS_THEN_GREEDY"
}

test_lazy() {
  LAZY_EXECX="$JAVA -Deat.ratio=$1 $LAZY_EXEC"

  check_and_start test_one_instance "$LAZY_EXECX" "LAZY$1"
}

test_greedy() {
  GREEDY_EXECX="$JAVA -Deat.ratio=$1 $GREEDY_EXEC"

  check_and_start test_one_instance "$GREEDY_EXECX" "GREEDY$1"
}

check_java() {
  JAVA=$(type -p java)
  RETCODE=$?

  if [ $RETCODE -ne 0 ]; then
    echo "$(date '+[%F %T]') ERROR: no JAVA found is system. Set up java properly." 1>&2
    exit 1
  fi
}

check_stress_ng() {
  STRESS=$(type -p stress-ng)
  RETCODE=$?

  if [ $RETCODE -ne 0 ]; then
    echo "$(date '+[%F %T]') ERROR: no STRESS-NG in system. Install it properly." 1>&2
    exit 1
  fi
}

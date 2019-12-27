#!/usr/bin/env bash
# Each iteration timeout
ITER_TIMEOUT=60

#vmstat delay and count
VMSTAT_DELAY=2
VMSTAT_CNT=5

# PIDs variables
FIRST_PID=-1
SECOND_PID=-1

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

  wait

  echo "$(date '+[%F %T]') Child processes killed. Exiting."
  exit 2
}

wait_and_print_vmstat() {
  local FIRST_PID=$1
  local SECOND_PID=$2
  local ITER_TIMEOUT=$3

  local DURATION=0
  while [ "$(ps "$FIRST_PID" "$SECOND_PID" | wc -l)" -gt 2 ]; do
    vmstat -w -S m -t "$VMSTAT_DELAY" "$VMSTAT_CNT"

    ((DURATION += VMSTAT_DELAY * VMSTAT_CNT))

    if [ $DURATION -gt "$ITER_TIMEOUT" ]; then
      echo "$(date '+[%F %T]') BOTH survived during timeout. Killing and perform next iteration..."

      kill "$FIRST_PID"
      kill "$SECOND_PID"

      wait

      break
    fi
  done

  return $DURATION
}

write_csv() {
  local FIRST_SURVIVED="$1"
  local SECOND_SURVIVED="$2"

  #       "Test name;Iteration started;Iteration finished;Iteration duration;Instance name;Survived;Instance PID;Command line;Instance started"
  echo "$TEST_NAME;$ITERATION_STARTED;$ITERATION_FINISHED;$ITERATION_DURATION;$FIRST_NAME;$FIRST_SURVIVED;$FIRST_PID;$FIRST;$FIRST_STARTED" >>"$CSV_FILE"
  echo "$TEST_NAME;$ITERATION_STARTED;$ITERATION_FINISHED;$ITERATION_DURATION;$SECOND_NAME;$SECOND_SURVIVED;$SECOND_PID;$SECOND;$SECOND_STARTED" >>"$CSV_FILE"
}

first_then_second() {
  local FIRST="$1"
  local FIRST_NAME="$2"
  local SECOND="$3"
  local SECOND_NAME="$4"
  local ITERS=$5
  local TEST_NAME=$6

  for ((i = 1; i < ITERS; i++)); do
    FIRST_PID=-1
    SECOND_PID=-1

    # Variables for CSV report
    local ITERATION_STARTED
    local FIRST_STARTED
    local SECOND_STARTED
    local ITERATION_FINISHED
    local ITERATION_DURATION

    ITERATION_STARTED="$(date '+%F %T')"
    echo -e "\n[$ITERATION_STARTED] Started test: firstly start $FIRST_NAME and then $SECOND_NAME:\t[iteration #$i]"

    $FIRST >/dev/null &
    FIRST_PID=$!
    FIRST_STARTED="$(date '+%F %T')"
    echo "[$FIRST_STARTED] $FIRST_NAME started: [PID: $FIRST_PID]"

    sleep 2

    $SECOND >/dev/null &
    SECOND_PID=$!
    SECOND_STARTED="$(date '+%F %T')"
    echo "[$SECOND_STARTED] $SECOND_NAME started: [PID: $SECOND_PID]"

    wait_and_print_vmstat $FIRST_PID $SECOND_PID "$ITER_TIMEOUT"
    ITERATION_DURATION="$?"

    ITERATION_FINISHED="$(date '+%F %T')"


    if [ $ITERATION_DURATION -gt "$ITER_TIMEOUT" ]; then
      write_csv "TRUE" "TRUE"

      continue
    fi

    local SURVIVED_PID=0
    if [[ $(ps "$SECOND_PID" | wc -l) -eq 2 ]]; then
      echo "$(date '+[%F %T]') $SECOND_NAME survived. Continue to new iteration..."

      SURVIVED_PID=$SECOND_PID

      write_csv "FALSE" "TRUE"
    elif [[ $(ps "$FIRST_PID" | wc -l) -eq 2 ]]; then
      echo "$(date '+[%F %T]') $FIRST_NAME survived. Continue to new iteration..."

      SURVIVED_PID=$FIRST_PID

      write_csv "TRUE" "FALSE"
    else
      echo "$(date '+[%F %T]') $FIRST_NAME and $SECOND_NAME PIDs count ERROR. Terminating..."

      kill -9 $SECOND_PID
      kill -9 $FIRST_PID

      exit 10
    fi

    kill "$SURVIVED_PID"

    wait
  done

  echo -e "$(date '+[%F %T]') Finished all tests: first $FIRST_NAME and then $SECOND_NAME"
}

lazy_then_greedy() {
  local LAZY="$1"
  local GREEDY="$2"
  local ITERS=$3

  first_then_second "$LAZY" "LAZY IGNITE" "$GREEDY" "GREEDY IGNITE" "$ITERS" "lazy_then_greedy"
}

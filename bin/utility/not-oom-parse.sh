#!/usr/bin/env bash

ROOT=$(realpath "$(dirname "$0")")

# Set up Apache logs path
if [ -n "$1" ]; then
	IGNITE_LOGS_DIR=$(realpath "$1")
else
	echo "You should specify Apache Ignite logs directory" 1>&2
	exit 1
fi

# Check and set PIDS_FILE and OVERCOMMIT_LOG paths
if [[ -n "$2" && -n "$3" ]]; then
	PIDS_FILE=$(realpath "$2")
	OVERCOMMIT_LOG=$(realpath "$3")
else
	echo "You should specify PIDs file and overcommit.log paths" 1>&2
	exit 1
fi

#Set up CSV report file
CSV_NAME=no-oom
if [ -n "$4" ]; then
	CSV_NAME="$4"
fi
CSV_FILE="$ROOT"/"$CSV_NAME".csv

exec > >(tee "$CSV_FILE")

while read -r PID; do
	echo -n "$PID;"
	FILE=$(grep -i "PID: $PID" "$IGNITE_LOGS_DIR"/*.log | head -1 | awk -F: '{print $1}')

	if [ -z "$FILE" ]; then
		PID_RECORD=$(grep -i "$PID" "$OVERCOMMIT_LOG" | head -1)

		if [ -n "$PID_RECORD" ]; then
			echo -n "$(basename "$OVERCOMMIT_LOG");"
			echo -n "$PID_RECORD"
		fi
	elif [ -n "$FILE" ]; then
		echo -n "$(basename "$FILE");"
		echo -n "$(grep "type=CRITICAL_ERROR, err=java.lang.OutOfMemoryError" "$FILE" | tail -n1)"
	fi
	echo ""
done < "$PIDS_FILE"

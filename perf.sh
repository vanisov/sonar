#!/bin/sh
# Checks the running Sonar against its idle budget. Close the popover and dashboard first.
# Usage: ./perf.sh [seconds]   (default 60)
set -e
SECONDS_TO_MEASURE="${1:-60}"
MAX_CPU=0.5      # % of one core
MAX_MEM_MB=60    # physical footprint
MAX_WAKEUPS=1    # idle wake-ups per second

PID=$(pgrep -x Sonar | head -1)
[ -n "$PID" ] || { echo "Sonar isn't running"; exit 1; }

# top's second sample averages over the whole interval. IDLEW is idle wake-ups in that interval.
LINE=$(top -l 2 -s "$SECONDS_TO_MEASURE" -pid "$PID" -stats cpu,mem,idlew | tail -1)
set -- $LINE
CPU=$1 MEM=$2 IDLEW=$3

MEM_MB=$(echo "$MEM" | awk '/G/ {print $1 * 1024; next} /K/ {print $1 / 1024; next} {print $1 + 0}')
WAKEUPS=$(echo "$IDLEW $SECONDS_TO_MEASURE" | awk '{printf "%.2f", $1 / $2}')

echo "cpu ${CPU}% (max ${MAX_CPU})  memory ${MEM_MB} MB (max ${MAX_MEM_MB})  wake-ups ${WAKEUPS}/s (max ${MAX_WAKEUPS})"
echo "$CPU $MEM_MB $WAKEUPS $MAX_CPU $MAX_MEM_MB $MAX_WAKEUPS" |
    awk '{ if ($1 > $4 || $2 > $5 || $3 > $6) { print "over budget"; exit 1 } else print "within budget" }'

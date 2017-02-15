#!/usr/bin/env bash

set -e
set -u

DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

USAGE="Usage: ./torch.sh [options] pid

Options:
-d, --duration <num>  duration of sampling in seconds [default: 10]
-e, --exec            instead of running script for duration, profile whole execution
-o, --output <file>   file to save flamegraph to [default: ./flamegraph.svg]
-h, --help            this message"

while [[ $# > 0 ]]
do
    case "$1" in
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -e|--exec)
            EXEC="yes"
            shift
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -h|--help)
            echo "$USAGE"
            exit 0
            ;;
        -*)
            echo "Error: Unkown Option $1" >&2
            echo "$USAGE" >&2
            exit 1
            ;;
        *)
            break
            ;;
    esac
done

PID=$1

if [[ -z "${PID:-}" ]] && [[ -z "${EXEC:-}" ]]
then
    echo "Error: pid is missing" >&2
    echo "$USAGE" >&2
    exit 1
fi

if [[ -z "${DURATION:-}" ]]
then
    DURATION=10
fi

if [[ -z "${OUTPUT:-}" ]]
then
    OUTPUT=./flamegraph.svg
fi

FREQ=199

function get_temp_file() {
    local tmppath=${1:-/tmp}
    local tmpfile=$2${2:+-}
    tmpfile=$tmppath/$tmpfile$RANDOM$RANDOM.tmp
    if [ -e $tmpfile ]
    then
        tmpfile=$(gettmpfile $1 $2)
    fi
    echo $tmpfile
}

TEMP_FILE=$(get_temp_file /tmp torch)

if [ -z "$EXEC" ]; then
	echo "sampling pid $PID for $DURATION seconds"
	perf record -o $TEMP_FILE -F $FREQ -p $PID -a --call-graph dwarf -- sleep $DURATION > /dev/null
else
	echo "profiling execution of $@"
	perf record -o $TEMP_FILE -F $FREQ -a --call-graph dwarf -- $@ > /dev/null
fi

echo "saving flame graph to $OUTPUT"
perf script -i $TEMP_FILE | "$DIR/stackcollapse-perf.pl" | "$DIR/flamegraph.pl" > $OUTPUT
echo "done."

rm -rf $TEMP_FILE

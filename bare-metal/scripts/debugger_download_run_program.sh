#!/bin/sh

hw_server 2>&1 &
sleep 5
xsdb ../scripts/debugger_download_run_program.tcl
sleep 5
PIDS=$(pgrep -x hw_server)
if [ -z "$PIDS" ]; then
    echo "[INFO] No hw_server process running."
    exit 0
fi

echo -e "[INFO] Found hw_server PIDs: \n$PIDS"
sleep 2
kill $PIDS
echo -e "[INFO] Killed"
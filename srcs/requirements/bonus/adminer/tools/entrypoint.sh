#!/bin/sh

# start simplistic php server in background
php83 -S 0.0.0.0:8081 -t /var/www/adminer/ &
PID=$!
# capture SIGTERM
trap "kill -SIGTERM $PID" SIGTERM
wait $PID
CODE=$?
if [ $CODE -eq 143 ]; then
    exit 0
fi
exit $CODE
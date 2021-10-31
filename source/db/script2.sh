#!/bin/bash -x

PROG=$(basename $0)
PIDFILE=/var/run/$PROG.pid
ENV=/home/vagrant/script2.sh.env

if [ "x$(whoami)" != "xroot" ]; then
  echo "Run this comand as 'root'"
  exit 1
fi

check() {
  if test -f $ENV; then . $ENV; fi
  # set resonable defaults
  if test -z "$CHECK_INTERVAL"; then CHECK_INTERVAL=30; fi
  if test -z "$NFILE_LIMIT"; then NFILE_LIMIT=3; fi
  # 100mb
  if test -z "$SIZE_LIMIT"; then SIZE_LIMIT=100000000; fi
  
  while true; do
    if test -d /local/backups; then
      if [ "$(find /local/backups -mindepth 1 -maxdepth 1 -type f | wc -l)" -gt $NFILE_LIMIT ]; then
        echo "WARN: /local/backups dir contains more then $NFILE_LIMIT files" | mail -s "Number of files in /local/backups exceed specified limit" root@localhost
      fi
      if [ "$(du -cbs /local/backups | grep total | awk '{ print $1 }')" -gt $SIZE_LIMIT ]; then
        echo "WARN: /local/backups content size is over $SIZE_LIMIT bytes" | mail -s "Size of files in /local/backups exceed specified limit" root@localhost
      fi
    fi
    sleep $CHECK_INTERVAL
  done 
}

case $1 in
start)
  if test -f $PIDFILE; then
    read pid < $PIDFILE
    if test -n "$pid"; then
      # process with this pid exists
      pid=$(ps axo pid | grep -w $pid)
      if [ -n "$pid" ] && [ "x$(ps axo pid,cmd | grep -w $pid | grep $PROG)" = "x$PROG" ]; then
        echo "$PROG already running. Pid $pid."
	exit 1
      fi
    else rm -v $PIDFILE; fi
  fi
  # Run command here
  check 2>/dev/null &
  pid=$!
  # Save programm pid to file
  echo $pid > $PIDFILE
  echo "$PROG is running -- ($pid)"
  ;;
stop)
  if test -f $PIDFILE; then
    read pid < $PIDFILE
    if test -n "$pid"; then
      if [ "x$(ps axo pid,cmd | grep -w $pid | grep -o $PROG)" = "x$PROG" ]; then
        kill -KILL $pid
	echo "Process $pid was killed"
	sudo rm -v $PIDFILE
	exit 0
      fi
    else sudo rm -v $PIDFILE; fi
  fi
  kill -KILL $(ps axo pid,cmd | grep $PROG | awk '{ print $1 }') 2>/dev/null
  exit 0
  ;;
*)
  echo "./$PROG start|stop"
  ;;
esac

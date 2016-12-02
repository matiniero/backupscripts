#!/bin/dash
. ./config

USAGE="USAGE: $0 [-f]\n-f zobrazit nazvy suborov"

BEFORE=`curl --silent -l "$FTPSERVER" | grep "$LOGFILE" | cut -d'-' -f1 | sort -r` 

if [ -z "$BEFORE" ]
then
  exit 1
else
  echo "$BEFORE" | while read BACKUP
  do
    if [ "$1" = "-f" ]
    then
      echo "$BACKUP-$LOGFILE"
    else 
      # zrekonstruujem datum a cas
      LASTYEAR=`echo "$BACKUP" | cut -c1-4`
      LASTMONTH=`echo "$BACKUP" | cut -c5-6`
      LASTDAY=`echo "$BACKUP" | cut -c7-8`

      LASTH=`echo "$BACKUP" | cut -c9-10`
      LASTM=`echo "$BACKUP" | cut -c11-12`
      LASTS=`echo "$BACKUP" | cut -c13-14`

      echo "$LASTYEAR/$LASTMONTH/$LASTDAY $LASTH:$LASTM:$LASTS"
    fi
  done
  exit 1
fi
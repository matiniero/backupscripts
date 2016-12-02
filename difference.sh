#!/bin/dash
. ./config

# datumy vo formate YYYY/MM/DD
DATEONE=$1
DATETWO=$2

USAGE="USAGE: $0 <YYYY/MM/DD> <YYYY/MM/DD> \nUSAGE: $0 <filename>"

TMPDIR="./temporary"
if [ ! -d "$TMPDIR" ]
then
  mkdir "$TMPDIR"
fi

# kontrola parametrov
if [ -z "$DATEONE" ]
then
  echo "first date missing..."
  echo "second date missing..."
  echo "$USAGE"
  rm -rf "$TMPDIR"
  exit 1
else
  if [ -z "$DATETWO" ]
  then
    if [ ! -f "$DATEONE" -o -z "$DATEONE" ]
    then
      echo "First parameter is not valid logfile..."
      echo "second date missing..."
      echo "$USAGE"
      rm -rf "$TMPDIR"
      exit 1
    else
      if [ ! -f "$1" ]
      then
	echo "Chybny subor $1..."
	rm -rf "$TMPDIR"
	exit 1
      fi
    fi
  fi
fi

if [ -n "$DATEONE" -a -n "$DATETWO" ]
then
  
  FIRSTDATE=`echo "$DATEONE" | sed 's|\/||g;s|:||g;s| ||g'`
  SECONDDATE=`echo "$DATETWO" | sed 's|\/||g;s|:||g;s| ||g'`

  # zistim ktora zaloha je mladsia a ktora starsia
  if [ "$FIRSTDATE" -lt "$SECONDDATE" ]
  then
    TMP="$FIRSTDATE"
    FIRSTDATE="$SECONDDATE"
    SECONDDATE="$TMP"
  fi
  
  MLADSI=`sh ./retrieve.sh -f | grep "$FIRSTDATE" | head -n1`
  STARSI=`sh ./retrieve.sh -f | grep "$SECONDDATE" | grep -v $MLADSI | head -n1`

  curl --silent --output "$TMPDIR/$MLADSI" "$FTPSERVER/$MLADSI"
  curl --silent --output "$TMPDIR/$STARSI" "$FTPSERVER/$STARSI"
else
# ak nezadam druhy datum tak prvy je nazov suboru s novymi logmi ktore porovnam s najnovsimi na servri
  cp "$1" "$TMPDIR/nova"
  MLADSI="nova"
  STARSI=`sh ./retrieve.sh -f | head -n1`
  curl --silent --output "$TMPDIR/$STARSI" "$FTPSERVER/$STARSI"
fi  


#if [ -n "$MLADSI" -a -n "$STARSI" ]
#then
  # toto su zmazane a zmenene
  DCH=`comm -13 "$TMPDIR/$MLADSI" "$TMPDIR/$STARSI" | cut -d' ' -f 3 | sort`
  echo "$DCH" > "$TMPDIR/uniq2"

  # toto su pridane a zmenene
  ACH=`comm -23 "$TMPDIR/$MLADSI" "$TMPDIR/$STARSI" | cut -d' ' -f 3 | sort`
  echo "$ACH" > "$TMPDIR/uniq1"

  #prienik 2 predoslych su zmenene
  ZMENENE=`comm -12 "$TMPDIR/uniq1" "$TMPDIR/uniq2" | sort`
  echo "$ZMENENE" > "$TMPDIR/changed"

  NEZMENENE=`comm -12 "$TMPDIR/$MLADSI" "$TMPDIR/$STARSI" | cut -d' ' -f 3 | sort`
  PRIDANE=`comm -23 "$TMPDIR/uniq1" "$TMPDIR/changed"`
  ZMAZANE=`comm -23 "$TMPDIR/uniq2" "$TMPDIR/changed"`
#fi

if [ -n "$PRIDANE" ]
then
  echo "$PRIDANE" | while read S
  do
    echo "$ADDEDCHAR $S"
  done
fi

if [ -n "$ZMENENE" ]
then
  echo "$ZMENENE" | while read S
  do
    echo "$CHANGEDCHAR $S"
  done
fi

if [ -n "$ZMAZANE" ]
then
  echo "$ZMAZANE" | while read S
  do
    echo "$DELETEDCHAR $S"
  done
fi

if [ -n "$NEZMENENE" ]
then
  echo "$NEZMENENE" | while read S
  do
    echo "$UNCHANGEDCHAR $S"
  done
fi

rm -rf "$TMPDIR"
exit 0
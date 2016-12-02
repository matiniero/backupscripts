#!/bin/dash
. ./config

DIR=$1

# casova peciatka
DATUM=`date +%Y%m%d%H%M%S`

# docasny adresar
TEMPDIR="./temp"

# novy log subor
NEWLOGNAME="$TEMPDIR/$DATUM-$LOGFILE"

USAGE="USAGE: $0 <folder>"

# 1. parameter musi byt zadany
if [ -z "$DIR" -o -f "$DIR" ]
then
  echo "$USAGE"
  exit 1
fi

# vytvorim docasny adresar na medzikroky ak este neexistuje
if [ ! -d "$TEMPDIR" ]
then
  mkdir "$TEMPDIR"
fi

# zoznam suborov v priecinku na zalohu
find "$DIR" -type f | while read SUBOR; 
do
  # pridam kontrolny sucet
  echo `cksum "$SUBOR"` >> "$DATUM"; 
done

# zotriedim logovaci subor
cat "$DATUM" | sort > "$NEWLOGNAME" && rm "$DATUM"

if [ `sh ./retrieve.sh -f | wc -l` -lt 1 ]
then
  echo "Ziadna predosla zaloha..."
  # zatarujem do docasneho priecinka
  tar -pczf "$TEMPDIR/$DATUM.tar.gz" "$DIR"

  # odoslem zalohovane subory na server
  echo "Posielam zalohu na server..."
  curl -T "$TEMPDIR/$DATUM.tar.gz" "$FTPSERVER"

  # odoslem logfile na server
  echo "Posielam logfile na server..."
  curl --silent -T "$NEWLOGNAME" "$FTPSERVER"

  # vymazem docasne subory
  rm -rf "$TEMPDIR"

  # vsetko OK
  exit 0
else
  echo "Existuje predosla zaloha..."
  PREDTYM=`sh ./difference.sh "$NEWLOGNAME"`
  
  ZMENY=`echo "$PREDTYM" | grep -v "$UNCHANGEDCHAR"`
  
  NOVEAZMENENE=`echo "$ZMENY" | grep -v "$DELETEDCHAR"`

  # ak su nejake rozdiely
  if [ -n "$ZMENY" ]
  then
  
    echo "$ZMENY"
    
    echo "$NOVEAZMENENE" | cut -d' ' -f2 | while read ZMENENYSUBOR
    do
      if [ -n "$ZMENENYSUBOR" ]
      then
	PRIECINOK=`echo "$ZMENENYSUBOR" | sed 's|\(.*\)/.*|\1|'`
	mkdir -p "$TEMPDIR/$PRIECINOK"
	mv "$ZMENENYSUBOR" "$TEMPDIR/$ZMENENYSUBOR"
      fi
    done
    
    # zatarujem do docasneho priecinka
    AKTUAL=`pwd`
    cd "$TEMPDIR"
    tar -pczf "$DATUM.tar.gz" "$DIR"
    cd "$AKTUAL"
    
    # presuniem subory spat na povodne miesto
    echo "$NOVEAZMENENE" | cut -d' ' -f2 | while read NOVYSUBOR
    do
      if [ -n "$NOVYSUBOR" ]
      then
	mv "$TEMPDIR/$NOVYSUBOR" "$NOVYSUBOR"
      fi
    done


    # odoslem zalohovane subory na server
    echo "Posielam zalohu na server..."
    curl -T "$TEMPDIR/$DATUM.tar.gz" "$FTPSERVER"

    # odoslem logfile na server
    echo "Posielam logfile na server..."
    curl --silent -T "$NEWLOGNAME" "$FTPSERVER"
    
    # vymazem docasne subory
    rm -rf "$TEMPDIR"

    # vsetko OK
    exit 0
  else
    # ak sa nic nezmenilo, nerobim nic
    echo "Ziadne zmeny..."
    # zmazem docasne subory
    rm -rf "$TEMPDIR"
    # vsetko OK
    exit 0
  fi
fi
# zmazem docasne subory
rm -rf "$TEMPDIR"
# vsetko OK
exit 0
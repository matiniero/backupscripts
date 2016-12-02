#!/bin/dash
. ./config

DATE=$1
FOLDER=$2

USAGE="USAGE: $0 <YYYY/MM/DD> <folder>"

if [ -z "$DATE" ]
then
  echo "$USAGE"
  exit 1
fi

if [ -z "$FOLDER" ]
then
  echo "$USAGE"
  exit 1
fi

if [ -d "$FOLDER" ]
then
  echo "Priecinok $FOLDER uz existuje, napriek tomu pokracovat? (y/n)"
  while read POTVRDENIE
  do
    if [ "$POTVRDENIE" = "y" ]
    then
      break
    fi
    
    if [ "$POTVRDENIE" = "n" ]
    then
      echo "zrusene pouzivatelom..."
      exit 1
    fi
  done
else
  mkdir "$FOLDER"
fi

DATESTAMP=`echo "$DATE" | sed 's/\///g;s/ //;s/://g'`

# vsetky zalohy od najnovsej po najstarsiu
VSETKYZALOHY=`sh ./retrieve.sh -f`

# posledna v dany den
POSLEDNA=`echo "$VSETKYZALOHY" | grep "$DATESTAMP" | head -n1`
MENOPOSLEDNEJ=`echo $POSLEDNA | cut -d'-' -f1`

if [ -z "$POSLEDNA" ]
then
  for LOGDATE in `echo "$VSETKYZALOHY" | cut -d'-' -f1`
  do
    # len pokym nenajdem najblizsiu predchadzajucu zalohu
    if [ -z "$POSLEDNA" ]
    then
      # 1. starsia na ktoru natrafim
      if [ "$LOGDATE" -lt "$DATESTAMP" ]
      then
	echo "Namiesto $DATESTAMP obnovujem zalohu $LOGDATE"
	DATESTAMP="$LOGDATE"
	POSLEDNA=`echo "$VSETKYZALOHY" | grep "$DATESTAMP" | head -n1`
	MENOPOSLEDNEJ=`echo $POSLEDNA | cut -d'-' -f1`
	break
      fi
    fi
  done
fi

# ak som ziadnu starsiu nenasiel
if [ -z "$POSLEDNA" ]
then
  echo "Ziadna zaloha z danej doby neexistuje..."
  exit 0
fi

# stiahnem log so zoznamom suborov ktore chcem obnovit
curl --silent -o "$FOLDER/$POSLEDNA" "$FTPSERVER/$POSLEDNA"

# vsetky subory ktore este treba stiahnut
CHYBAJUCE=`cat "$FOLDER/$POSLEDNA"`
POCET=`cat "$FOLDER/$POSLEDNA" | wc -l`

# cislo riadku zalohy na obnovenie v zozname zaloh
POZICIA=`echo "$VSETKYZALOHY" | grep -n "$POSLEDNA" | cut -d':' -f1`

# najprv vytvorim potrebne priecinky
echo "$CHYBAJUCE" | cut -d' ' -f3 | while read PRIEC
do
  mkdir -p "$FOLDER/`echo $PRIEC | sed 's|\(.*\)/.*|\1|'`"
done

echo "$VSETKYZALOHY" | tail -n$((`echo "$VSETKYZALOHY" | wc -l`-$POZICIA+1)) | while read LOG
do
  if [ -n "$LOG" ]
  then
    NAZOV="`echo $LOG | sed s/-$LOGFILE//g`.tar.gz"
    
    # len casova peciatka zo zalohy
    MENOPREZERANEJ=`echo "$LOG" | cut -d'-' -f1`
    
    PORADIEPREZERANEHO=`echo "$VSETKYZALOHY" | grep -n "$MENOPREZERANEJ" | cut -d':' -f1`
    if [ "$PORADIEPREZERANEHO" -lt `echo "$VSETKYZALOHY" | wc -l` ]
    then
      PREDOSLELOGY=`echo "$VSETKYZALOHY" | cut -d'-' -f1 | head -n$(($PORADIEPREZERANEHO+1)) | tail -n1`
    else
      PREDOSLELOGY=""
    fi
    
    if [ -n "$PREDOSLELOGY" ]
    then
      # ak pocet zmien medzi zalohou ktoru chcem tahat a predchadzajucou zalohou je 0, mozem ju vynechat lebo neobsahuje ziadne subory
      POCETZMIEN=`sh ./difference.sh "$MENOPREZERANEJ" "$PREDOSLELOGY" | grep -v "$UNCHANGEDCHAR" | grep -v "$DELETEDCHAR" | wc -l`
    else
      # ak neexistuju predosle logy dam pocet zmien > 0 aby sa zaloha nutne stiahla
      POCETZMIEN=1
    fi
    
    if [ "$POCETZMIEN" -eq 0 ]
    then
      echo "Ziadne zmeny medzi $MENOPREZERANEJ a $PREDOSLELOGY, $MENOPREZERANEJ netreba tahat"
    else
      echo "stahujem zalohu $NAZOV"
      curl --silent -o "$FOLDER/$NAZOV" "$FTPSERVER/$NAZOV"
      
      #echo "stahujem logfile $LOG"
      #curl --silent -o "$FOLDER/$LOG" "$FTPSERVER/$LOG"
      
      CIEL="$FOLDER/`echo $LOG | sed s/-$LOGFILE//g`"
      mkdir "$CIEL"
	
      CHYBAJUCE=`cat "$FOLDER/$POSLEDNA"`
	
      # pri rozbalovani zistim ci mam spravne subory
      tar -zxvf "$FOLDER/$NAZOV" -C "$CIEL" | while read STIAHNUTE
      do
	# ak je retazec nenulovy a nie je to priecinok
	if [ -n "$STIAHNUTE" -a ! -d "$STIAHNUTE" ]
	then
	  # prejdem vsetky zhody a najdem spravnu
	  echo "$CHYBAJUCE" | grep "$STIAHNUTE" | while read MOZNOST
	  do
	    if [ -n "$MOZNOST" ]
	    then
	      MENO=`echo "$MOZNOST" | cut -d' ' -f3`
	      if [ "$MENO" = "$STIAHNUTE" ]
	      then
		# nasiel som zhodu v nazve
		ZHODA=$MOZNOST

		# zapamatam si priecinok kde som bol a vleziem tam kde stahujem
		AKTUAL=`pwd`
		cd "$CIEL"
		
		SUCET=`cksum "$STIAHNUTE"`
		
		# ak mam rovnaky kontrolny sucet ako v logu
		if [ "$ZHODA" = "$SUCET" ]
		then
		  # znamena ze mam spravny subor, mozem ho odstranit z chybajucich
		  cd "$AKTUAL"
		  cat "$FOLDER/$POSLEDNA" | grep -v "$ZHODA" > "$FOLDER/tmp$POSLEDNA"
		  cat "$FOLDER/tmp$POSLEDNA" > "$FOLDER/$POSLEDNA"
		  rm "$FOLDER/tmp$POSLEDNA"
		  cd "$CIEL"
		  
		  # treba ho presunut o adresar vyssie
		  mv "$MENO" "../$MENO"
		else
		  # nie je to spravny subor
		  rm "$STIAHNUTE"
		  #echo "Kontrolne sucty sa nezhoduju... $ZHODA != $SUCET"
		fi
		
		# vratim sa spat kde som bol
		cd "$AKTUAL"
		
	      fi
	    fi
	  done
	fi
      done

      # odstranim stiahnuty archiv
      rm "$FOLDER/$NAZOV"
      
      if [ "$CIEL" != "$FOLDER" ]
      then
	rm -rf "$CIEL"
      fi
    
      # skontrolujem ci uz mam vsetko
      if [ -n "`cat "$FOLDER/$POSLEDNA" | sed 's/ //g'`" ]
      then
	echo "este chybaju subory... (`cat "$FOLDER/$POSLEDNA" | wc -l`)"
      else
	rm "$FOLDER/$POSLEDNA"
	echo "vsetky subory stiahnute... ($POCET)"
	exit 0
      fi

    fi # ak su nejake zmeny
  else
    echo "Ziadna vyhovujuca zaloha..."
    exit 1
  fi
done

exit 0
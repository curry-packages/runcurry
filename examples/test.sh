#!/bin/sh
# Shell script to test the current set of examples

# Root location of the Curry System specified by variable CURRYROOT
CURRYROOT=`curry :set v0 :set -time :add Distribution :eval "putStrLn installDir" :quit`

CURRYBIN=$CURRYROOT/bin

if [ -x "$CURRYBIN/pakcs" ] ; then
    CURRYEXEC=pakcs
elif [ -x "$CURRYBIN/kics2" ] ; then
    CURRYEXEC=kics2
else
    echo "ERROR: Unknown Curry system!"
    exit 1
fi

VERBOSE=no
if [ "$1" = "-v" ] ; then
  VERBOSE=yes
fi

LOGFILE=xxx$$
PATH=$CURRYBIN:$PATH
export PATH
$CURRYBIN/cleancurry
rm -f $LOGFILE

cat << EOM | /bin/sh > $LOGFILE
runcurry Test.curry rtarg1 rtarg2
cat Test.curry | runcurry
echo "main = print 42" | runcurry
./curryscript.sh Hello World
./curryscript.sh Hi World
EOM

################ end of tests ####################
# Clean:
/bin/rm -f curryscript.sh.bin

if [ $VERBOSE = yes ] ; then
    cat $LOGFILE
    echo
fi

# Check differences:
DIFF=diff$$
diff TESTRESULT.$CURRYEXEC $LOGFILE > $DIFF
if [ "`cat $DIFF`" = "" ] ; then
  echo "Regression test successfully executed!"
  /bin/rm -f $LOGFILE $DIFF
  $CURRYBIN/cleancurry
else
  echo "DIFFERENCES IN REGRESSION TEST OCCURRED:"
  cat $DIFF
  /bin/rm -f $DIFF
  /bin/mv -f $LOGFILE LOGFILE
  echo "Test output saved in file 'LOGFILE'."
  $CURRYBIN/cleancurry
  exit 1
fi

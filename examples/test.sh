#!/bin/sh
# Shell script to test the current set of 'runcurry' examples

# Compute bin directory of the Curry System:
CURRYBINDIR=$(dirname $(realpath $CURRYBIN))

VERBOSE=no
if [ "$1" = "-v" ] ; then
  VERBOSE=yes
fi

LOGFILE=xxx$$
PATH=$CURRYBINDIR:$PATH
export PATH
$CURRYBINDIR/cleancurry
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
diff TESTRESULT.txt $LOGFILE > $DIFF
if [ "`cat $DIFF`" = "" ] ; then
  echo "Regression test successfully executed!"
  /bin/rm -f $LOGFILE $DIFF
  $CURRYBINDIR/cleancurry
else
  echo "DIFFERENCES IN REGRESSION TEST OCCURRED:"
  cat $DIFF
  /bin/rm -f $DIFF
  /bin/mv -f $LOGFILE LOGFILE
  echo "Test output saved in file 'LOGFILE'."
  $CURRYBINDIR/cleancurry
  exit 1
fi

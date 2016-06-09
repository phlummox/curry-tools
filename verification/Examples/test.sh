#!/bin/sh
# Shell script to test the current set of examples

CURRYBIN="../../../bin"

AGDACHOICETESTS="Double EvenOdd MyList Perm"
AGDANONDETTESTS="$AGDACHOICETESTS Game"

VERBOSE=no
if [ "$1" = "-v" ] ; then
  VERBOSE=yes
fi

# use the right Curry system for the tests:
PATH=$CURRYBIN:$PATH
export PATH

LOGFILE=xxx$$

# clean up before
$CURRYBIN/cleancurry
rm -f TO-PROVE-* $LOGFILE


# execute all tests:
# Check whether the Agda compiler compiles the generated programs.
AGDA=`which agda`
AGDAIMPORTS="-i . -i /home/mh/home/languages_systems/agda/ial -i /usr/share/agda-stdlib"
AGDAOPTS="--allow-unsolved-metas"

if [ -z "$AGDA" ] ; then
  echo "WARNING: cannot check curry2verify ('agda' not found)"
  exit
fi

compile_to_agda()
{
  PROG=$1
  # curry2very options:
  CVOPTS=$2
  if [ $VERBOSE = yes ] ; then
    $CURRYBIN/curry2verify -t agda $CVOPTS $PROG
    $AGDA $AGDAIMPORTS $AGDAOPTS TO-PROVE-*
    if [ $? -gt 0 ] ; then
      exit 1
    fi
  else
    $CURRYBIN/curry2verify -t agda $CVOPTS $PROG >> $LOGFILE 2>&1
    $AGDA $AGDAIMPORTS $AGDAOPTS TO-PROVE-* >> $LOGFILE 2>&1
    if [ $? -gt 0 ] ; then
      echo "ERROR in curry2verify:"
      cat $LOGFILE
      exit 1
    fi
  fi
  /bin/rm -f TO-PROVE-*
}

for CP in $AGDACHOICETESTS ; do
  compile_to_agda $CP "-s choice"
done
for CP in $AGDANONDETTESTS ; do
  compile_to_agda $CP "-s nondet"
done

################ end of tests ####################
# Clean:
$CURRYBIN/cleancurry
/bin/rm -f $LOGFILE nondet.agda*
#!/bin/bash
[[ $(uname) == 'Darwin' ]] && sedexflag='-E' || sedexflag='-r'
mkdir -p ./build
source ./src/preamble.sh
TARGET=./build/zbackup.sh
echo Building zBackup $VERSION...
cp ./src/preamble.sh $TARGET
files=$(ls ./src | sed 's|preamble.sh||')
for f in $files
do
  echo Adding $f...
  cat ./src/$f | sed $sedexflag '/^([[:space:]]*#.*)?$/d' >> $TARGET
done
echo 'main $@' >> $TARGET
chmod +x $TARGET
echo Build done.

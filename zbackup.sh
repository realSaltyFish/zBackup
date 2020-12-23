#!/bin/bash


TODAY=$(date +%Y%m%d)
VERSION=0.0.1


function output()
{
  local CONTENT=$1
  local COLOR=$2
  case "$COLOR" in
    green)
      local PREFIX='\033[0;32m';;
    red)
      local PREFIX='\033[0;31m';;
    yellow)
      local PREFIX='\033[1;33m';;
    *)
      local PREFIX='';;
  esac
  local POSTFIX='\033[0m'
  echo -e $PREFIX$CONTENT$POSTFIX
  return
}


function snapshot()
{
  local failed
  for DATASET in $DATASETS
  do
    echo Creating snapshot $DATASET@$TODAY
    zfs snapshot $DATASET@$TODAY
    if [ $? != 0 ]
    then
      output "Error creating snapshot." red
      failed=true
    fi
  done
  if [ $failed ]
  then
    output "Finished creating shapshots with one or more errors." yellow
  else
    output "Finished creating shapshots." green
  fi
}


function send()
{
  local failed
  for DATASET in $DATASETS
  do
    echo Exporting snapshot $DATASET@$TODAY to $STORAGE/$DATASET/
    mkdir -p $STORAGE/$DATASET/$TODAY
    cd $STORAGE/$DATASET/$TODAY
    if [ $? != 0 ]
    then
      output "Error reaching the target directory." red
      failed=true
    fi
    zfs send -w $DATASET@$TODAY | gzip -c | split -b 10G -d - backup.zfs.gz_part
    if [ $? != 0 ]
    then
      output "Error exporting the dataset." red
      failed=true
    fi
  done
  if [ $failed ]
  then
    output "Finished exporting snapshots with one or more errors." yellow
  else
    output "Finished exporting snapshots." green
  fi
}


function upload()
{
  local this_failed
  local failed
  for DATASET in $DATASETS
  do
    echo Uploading snapshot stored at $STORAGE/$DATASET/$TODAY/ to $DEST/$DATASET/$TODAY/
    for f in $(ls $STORAGE/$DATASET/$TODAY)
    do
      rclone copy $STORAGE/$DATASET/$TODAY/$f $DEST/$DATASET/$TODAY/ -P --onedrive-chunk-size=240M
      if [ $? != 0 ]
      then
        output "Error uploading $f" red
        failed=true
        this_failed=true
        break
      fi
    done
    if [ -z $this_failed ]
    then
      output "Uploaded snapshot $DATASET@$TODAY." green
    fi
  done
  if [ $failed ]
  then
    output "Finished uploading snapshots with one or more errors." yellow
  else
    output "Finished uploading snapshots." green
  fi
}


function main()
{
  _setArgs $@
  DATASETS=$(zfs get -r backup:auto $POOL | grep -P "^($POOL\/[^@|\s]+)\s*[^\s]+\s*true" | grep -o -P "$POOL/[^\s]+")
  output "Datasets to process: $DATASETS" yellow
  if [ $DO_SNAPSHOT ]
  then
    snapshot
  fi
  if [ $DO_EXPORT ]
  then
    send
  fi
  if [ $DEST ]
  then
    upload
  fi
}


function _setArgs(){
  while [ "${1:-}" != "" ]; do
    case "$1" in
      "-h" | "--help")
        _help
        ;;
      "--version" )
        _version
        ;;
      "-p" | "--pool")
        shift
        POOL=$1
        ;;
      "-s" | "--snapshot")
        DO_SNAPSHOT=true
        ;;
      "-e" | "--export")
        DO_EXPORT=true
        ;;
      "-t" | "--storage")
        shift
        STORAGE=$1
        if [ ! -d $STORAGE ]
        then
          echo Invalid backup storage position.
          exit 1
        fi
        ;;
      "-u" | "--upload")
        shift
        DEST=$1
        # TODO: Check the validity of $DEST
        ;;
      "-d" | "--date")
        shift
        TODAY=$1
        echo Specified date $TODAY.
        ;;
    esac
    shift
  done
  if [ -z $POOL ]
  then
    echo Please specify a pool to operate on. Use -h or --help for help.
    exit 1
  fi
  if ([ $DEST ] || [ $DO_EXPORT ]) && [ -z $STORAGE ]
  then
    echo Please specify the location of backup files for exporting/uploading.
    exit 1
  fi
}


function _help()
{
  echo '
  zBackup '$VERSION' written by Salty Fish
  A lightweight ZFS backup tool.

  Usage: zbackup.sh -p POOL [-t|--storage STORAGE] [-u|--upload DESTINATION] [-s|--snapshot]
                    [-e|--export] [-d|--date DATE] [-h|--help] [--version]
  '
  exit 0
}


function _version()
{
  echo zBackup $VERSION written by Salty Fish
  exit 0
}


main $@

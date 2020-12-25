#!/bin/bash


TODAY=$(date +%Y%m%d)
VERSION=0.2.0


function output()
# A utility function. Prints content with assigned color.
# $1: content to display
# $2: color (one of red, green, yellow)
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


function printHeader()
# A utility function. Prints a header with assigned content in the middle.
# $1: content in the middle
{
  local CONTENT=$1
  echo -e '\n|'----------$CONTENT----------'|\n'
}


function snapshot()
# Creates snapshots.
# Using: $DATASETS, $TODAY, $DRY_RUN
{
  printHeader SNAPSHOTTING
  local failed
  for DATASET in $DATASETS
  do
    echo Creating snapshot $DATASET@$TODAY
    if [ -z $DRY_RUN ]
    then
      zfs snapshot $DATASET@$TODAY
    fi
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
# Exports snapshots to assigned location.
# Using: $DATASETS, $TODAY, $DRY_RUN, $STORAGE
{
  printHeader EXPORTING
  local failed
  for DATASET in $DATASETS
  do
    echo Exporting snapshot $DATASET@$TODAY to $STORAGE/$DATASET/
    mkdir -p $STORAGE/$DATASET/$TODAY && cd $STORAGE/$DATASET/$TODAY
    if [ $? != 0 ]
    then
      output "Error reaching the target directory." red
      failed=true
    fi
    if [ -z $DRY_RUN ]
    then
      zfs send -w $DATASET@$TODAY | gzip -c | split -b 10G -d - backup.zfs.gz_part
    fi
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
# Uploads exported snapshots to assigned remote location.
# Depends on: rclone
# Using: $DATASETS, $TODAY, $DRY_RUN, $STORAGE, $DEST
{
  printHeader UPLOADING
  local this_failed
  local failed
  for DATASET in $DATASETS
  do
    echo Uploading snapshot stored at $STORAGE/$DATASET/$TODAY/ to $DEST/$DATASET/$TODAY/
    if [ -z $DRY_RUN ]
    then
      local files=$(ls $STORAGE/$DATASET/$TODAY)
      if [ $? -ne 0 ]
      then
        output "Error reaching directory $STORAGE/$DATASET/$TODAY" red
        failed=true
        continue
      fi
      for f in $files
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
    fi
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


function cleanSnapshots()
# Cleans snapshots with the assigned policy.
# Using: $DATASETS, $DRY_RUN, $AUTO_CONFIRM, $CLEAN_POLICY
{
  printHeader CLEANING
  local MODE
  local ARG
  local VICTIMS=()
  if [ $(echo $CLEAN_POLICY | grep -P "keep\d+") ] # policy is keep*
  then
    MODE=number
    ARG=$(echo $CLEAN_POLICY | sed 's|keep||')
    echo Cleaning policy: Keep latest $ARG snapshots.
  elif [ $(echo $CLEAN_POLICY | grep -P "before\d{8}") ] # policy is before*
  then
    MODE=date
    ARG=$(echo $CLEAN_POLICY | sed 's|before||')
    echo Cleaning policy: Keep snapshots from date $ARG.
  else
    echo Invalid cleaning policy. Not doing anything.
    return
  fi
  for DATASET in $DATASETS
  do
    echo Searching for snapshots of $DATASET...
    # search for snapshots
    readarray -t -d '\n' _SNAPSHOTS <<< $(zfs list -t snapshot $DATASET | grep -P -o "^$DATASET@\d{8}\s+" | sed 's|\ ||')
    # sort the snapshots
    IFS='\n'
    readarray SNAPSHOTS <<< $(sort -r <<< "${_SNAPSHOTS[*]}")
    unset IFS
    echo Found snapshots: ${SNAPSHOTS[*]}
    case $MODE in
      number)
        VICTIMS+=${SNAPSHOTS[*]:$ARG}
        ;;
      date)
        for SNAPSHOT in ${SNAPSHOTS[*]}
        do
          if [[ $SNAPSHOT < "$DATASET@$ARG" ]]
          then
            VICTIMS+=($SNAPSHOT)
          fi
        done
        ;;
    esac
  done
  output "Snapshots to destroy: ${VICTIMS[*]}" yellow
  local failed
  if [ -z $AUTO_CONFIRM ]
  then
    while true
    do
      read -p "Perform the cleanup? (Y/n) " CONFIRM
      case $CONFIRM in
        Y|y|yes|Yes)
          break
          ;;
        N|n|no|No)
          echo Aborting.
          return
          ;;
        *)
          echo "Say yes or no."
          ;;
      esac
    done
  else
    echo Automatically confirmed by flag -y or --yes.
  fi
  for VICTIM in ${VICTIMS[*]}
  do
    echo Destroying $VICTIM...
    if [ -z $DRY_RUN ]
    then
      zfs destroy $VICTIM
    fi
    if [ $? -ne 0 ]
    then
      output "Failed to destroy $VICTIM" red
      failed=true
    fi
  done
  if [ $failed ]
  then
    output "Finished cleaning up snapshots with one or more errors." yellow
  else
    output "Finished cleaning up snapshots." green
  fi
}


function main()
{
  unset_vars
  case $1 in
    "-h"|"--help")
      _help
      ;;
    "--version")
      _version
      ;;
  esac
  printHeader HELLO
  read_args $@
  get_datasets
  echo Datasets to process: $DATASETS
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
  if [ $CLEAN_POLICY ]
  then
    cleanSnapshots
  fi
  printHeader BYE
}


function get_datasets()
# Finds all datasets to process and store in the global variable $DATASETS.
# Using: $FS, $POOL
{
  if [ $FS ]
  then
    DATASETS=$(printf "%s " "${FS[@]}")
  else
    DATASETS=$(zfs get -r zbackup:enabled $POOL | grep -P -o "^$POOL\/[^@\s]+(?=\s+[\w:]+\s+true)")
  fi
}


function read_args()
# Reads and parses all arguments. Should be called only once from main().
{
  while [ "${1:-}" != "" ]
  do
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
        zfs list $POOL > /dev/null
        if [ $? -ne 0 ]
        then
          output "Invalid pool $POOL" red
          _exit 1
        fi
        ;;
      "-f" | "--dataset" | "--fs")
        FS=()
        while [[ $(echo $2 | grep -P "^[^-]") ]] # not another argument
        do
          if [ $(echo $2 | grep -P -o "^\w+\/\w+$") ]
          then
            zfs list $2 > /dev/null
            if [ $? -eq 0 ]
            then
              FS+=($2)
              shift
              continue
            fi
          fi
          echo Invalid dataset $2 ignored.
          shift
        done
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
          _exit 1
        fi
        ;;
      "-u" | "--upload")
        shift
        DEST=$1
        if [ -z $(echo $DEST | grep -P '\w+:(\w+\/?)+') ]
        then
          echo Invalid upload destination $DEST
          _exit 1
        fi
        ;;
      "-c" | "--clean")
        shift
        CLEAN_POLICY=$1
        ;;
      "--date")
        shift
        TODAY=$1
        if [ $(echo $TODAY | grep -P '^\d{8}$') ]
        then
          echo Specified date $TODAY.
        else
          echo Invalid date $TODAY. Use 8 digits to represent a date, e.g. 20201123
          _exit 1
        fi
        ;;
      "-y" | "--yes")
        AUTO_CONFIRM=true
        ;;
      "-d" | "--dry")
        DRY_RUN=true
        output "Dry run - will not actually do anything." yellow
        ;;
    esac
    shift
  done
  if [ -z $POOL ] && [ -z $FS ]
  then
    echo Please specify a pool or dataset to operate on. Use -h or --help for help.
    _exit 1
  fi
  if [ $FS ] && [ $POOL ]
  then
    output "Pool and dataset specified simultaneously. Pool will be ignored." yellow
  fi
  if ([ $DEST ] || [ $DO_EXPORT ]) && [ -z $STORAGE ]
  then
    echo Please specify the location of backup files for exporting/uploading.
    _exit 1
  fi
}


function unset_vars()
# Unsets all global variables used. Should be called only once from main().
{
  unset AUTO_CONFIRM
  unset DEST
  unset STORAGE
  unset FS
  unset POOL
  unset DO_EXPORT
  unset DO_SNAPSHOT
  unset DATASETS
  unset DATASET
  unset DRY_RUN
}


function _help()
# Prints the help message.
{
  echo '
  zBackup '$VERSION' written by Salty Fish
  A lightweight ZFS backup tool.

  Usage: zbackup.sh [-p|--pool POOL] [-d|--fs|--dataset DATASET1 DATASET2 ...] [-t|--storage STORAGE]
                    [-u|--upload DESTINATION] [-s|--snapshot] [-e|--export] [-c|--clean POLICY]
                    [--date DATE] [-y|--yes] [-d|--dry] [-h|--help] [--version]
  '
  exit 0
}


function _version()
# Prints the version message.
{
  echo zBackup $VERSION written by Salty Fish
  exit 0
}


function _exit()
# Prints the error header and exits.
# $1: exit code
{
  printHeader ERROR
  exit $1
}


main $@

#!/bin/bash
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

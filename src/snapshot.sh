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

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

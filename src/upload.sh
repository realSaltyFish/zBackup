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

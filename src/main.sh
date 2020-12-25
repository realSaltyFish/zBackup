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



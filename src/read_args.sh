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

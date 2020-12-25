function _help()
# Prints the help message.
{
  echo '
  zBackup '$VERSION' written by Salty Fish
  A lightweight ZFS backup tool.

  Usage: zbackup.sh [-p|--pool POOL] [-f|--fs|--dataset DATASET1 DATASET2 ...] [-t|--storage STORAGE]
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

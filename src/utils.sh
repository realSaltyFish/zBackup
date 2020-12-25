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


function _exit()
# A utility function. Prints the error header and exits.
# $1: exit code
{
  printHeader ERROR
  exit $1
}

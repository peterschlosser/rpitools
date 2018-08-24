#!/bin/bash

# enables HTACCESS overrides in default apache 2 server configuration
# with debian raspberry pi operating systems.
# normally .htaccess overrides are disabled by default.
# this script sudos to root and makes the change to apache config
# and restarts the server. .htaccess directives should then begin
# working under /var/www/html/
#
# within apache server configuartion (/etc/apache2/apache2.conf)
# for directory /var/www/ (DOCUMENT_ROOT)
# translate from:
#	<Directory /var/www/>
#	        Options Indexes FollowSymLinks
#	        AllowOverride None
#	        Require all granted
#	</Directory>
# translate to:
#	<Directory /var/www/>
#	        Options Indexes FollowSymLinks
#	#       AllowOverride None
#	        AllowOverride AuthConfig
#	        Require all granted
#	</Directory>

WWW_CFG=/etc/apache2/apache2.conf
CMD_APCHECTL=/usr/sbin/apachctl
CMD_AWK=/usr/bin/awk
CMD_GREP=/bin/grep
CMD_LS=/bin/ls
CMD_MV=/bin/mv
CMD_RM=/bin/rm
CMD_SED=/bin/sed
CMD_SH=/bin/sh
CMD_SUDO=/usr/bin/sudo
CMD_TAIL=/usr/bin/tail
CMD_XARGS=/usr/bin/xargs
SED_SELECT="/<Directory \/var\/www\/>/,/<\/Directory>/"

# rotates renames files using path to base file.
# example, given $1=/path/to/file
# remove /path/to/file.5 or greater 
# rename /path/to/file.4 to /path/to/file.5
# rename /path/to/file.3 to /path/to/file.4
# rename /path/to/file.2 to /path/to/file.3
# rename /path/to/file.1 to /path/to/file.2
# rename /path/to/file   to /path/to/file.1
function rotate()
{
  local BN=$1
  $CMD_LS -1 ${BN}* | $CMD_TAIL -n +5 | $CMD_XARGS $CMD_RM > /dev/null 2>&1
  for i in {4..1}; do
    SRC="${BN}.${i}"
    DST="${BN}.$((i+1))"
    if [ -f "${SRC}" ]; then
      $CMD_SUDO $CMD_MV $SRC $DST
    fi
  done
  if [ -f "${BN}" ]; then
    $CMD_SUDO $CMD_MV "${BN}" "${BN}.1"
    echo "${BN}.1"
  fi
}

# has uncommented "AllowOverride None"
$CMD_AWK "${SED_SELECT}" $WWW_CFG | \
  $CMD_GREP -q -P "^\s+AllowOverride\s+None"
HTACCESS_NONE=$(( $? == 0 ? 1 : 0 ))

# has desired "AllowOverride AuthConfig"
$CMD_AWK "${SED_SELECT}" $WWW_CFG | \
  $CMD_GREP -q -P "^\s+AllowOverride\s+AuthConfig"
HTACCESS_ENABLED=$(( $? == 0 ? 1 : 0 ))

if [[ HTACCESS_NONE -eq 0 && HTACCESS_ENABLED -eq 0 ]]; then
  # missing "AllowOverride None" and
  # missing "AllowOverride AuthConfig"
  echo "Unexpected Apache AllowOverride state. Aborting."
  exit 1
fi

if [[ HTACCESS_NONE -eq 1 || HTACCESS_ENABLED -eq 0 ]]; then
  WWW_CFG1=$(rotate $WWW_CFG)
  # comment out "AllowOverride None" and 
  # append "AllowOverride AuthConfig"
#  $CMD_SUDO \
#    $CMD_SED -e "${SED_SELECT}s/\([[:space:]]\+AllowOverride None\)/#\1\n\tAllowOverride AuthConfig/" \
#      $WWW_CFG1 > $WWW_CFG
  $CMD_SUDO \
    $CMD_SH \
    -c "${CMD_SED} -e \"${SED_SELECT}s/\([[:space:]]\+AllowOverride None\)/#\1\n\tAllowOverride AuthConfig/\" ${WWW_CFG1} > ${WWW_CFG}"
#  $CMD_SUDO \
#    $CMD_APCHECTL restart
fi

echo "htaccess directives enabled."

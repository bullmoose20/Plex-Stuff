#!/bin/bash
# Original code written by the crew at [REDACTED] and good to share because `This is the way` https://www.youtube.com/watch?v=1iSz5cuCXdY
# Sharing as is... you will need to tweak this as I have never run it and I am on Unraid running hotio plex container

sqplex="/mnt/user/data/scripts/plex-scripts/pumpanddump/plexsql/plexmediaserver/Plex Media Server"

function usage {
  echo ""
  echo "Usage: pumpandump.sh plex "
  echo ""
  echo "where plex is the name of your plex docker container, plex plex2 plex3"
  exit 1
}

if [ -z "$1" ]; then
  echo "please provide the name of your plex docker container"
  usage
fi
# install JQ if not installed
if hash jq 2> /dev/null; then echo "OK, you have jq installed. We will use that."; else sudo apt install jq -y; fi

dbp1=$(docker inspect "${1}" | jq -r ' .[].HostConfig.Binds[] | select( . | contains("/config:rw"))')
dbp1=${dbp1%%:*}
dbp1=${dbp1#/}
dbp1=${dbp1%/}
dbp2="Plug-in Support/Databases"
dbpath="${dbp1}/${dbp2}"
plexdbpath="/${dbpath}"
USER=$(stat -c '%U' "$plexdbpath/com.plexapp.plugins.library.db")
GROUP=$(stat -c '%G' "$plexdbpath/com.plexapp.plugins.library.db")
plexdocker="${1}"

echo "perms on db are $USER:$GROUP"
echo "${plexdbpath}"
echo "${plexdocker}"
echo "stopping ${plexdocker}"

docker stop "${plexdocker}"
echo "copying plex app"
docker cp "${plexdocker}":/app/usr/lib/plexmediaserver/ /mnt/user/data/scripts/plex-scripts/pumpanddump/plexsql
cd "$plexdbpath" || exit
echo "backing up database"
cp com.plexapp.plugins.library.db com.plexapp.plugins.library.db.original
echo "cleaning/resetting folders"
rm -rf "/${dbp1}"/Codecs/*
echo "removing pointless items from database"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "DROP index 'index_title_sort_naturalsort'"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "DELETE from schema_migrations where version='20180501000000'"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "DELETE FROM statistics_bandwidth;"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "DELETE FROM statistics_media;"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "DELETE FROM statistics_resources;"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "DELETE FROM accounts;"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "DELETE FROM devices;"
echo "fixing dates on stuck files"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "UPDATE metadata_items SET added_at = originally_available_at WHERE added_at <> originally_available_at AND originally_available_at IS NOT NULL;"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "UPDATE metadata_items SET added_at = DATETIME('now', '-1 days') WHERE DATETIME(added_at) > DATETIME('now');"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "UPDATE metadata_items SET added_at = DATETIME('now', '-1 days') WHERE DATETIME(originally_available_at) > DATETIME('now');"
echo "dumping and removing old database"
"${sqplex}" --sqlite com.plexapp.plugins.library.db .dump > dump.sql
rm com.plexapp.plugins.library.db
echo "making adustments to new db"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "pragma page_size=32768; vacuum;"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "pragma default_cache_size = 20000000; vacuum;"
echo "importing old data"
"${sqplex}" --sqlite com.plexapp.plugins.library.db <dump.sql
echo "optimize database and fix times"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "vacuum"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "pragma optimize"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "UPDATE metadata_items SET added_at = originally_available_at WHERE added_at <> originally_available_at AND originally_available_at IS NOT NULL;"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "UPDATE metadata_items SET added_at = DATETIME('now', '-1 days') WHERE DATETIME(added_at) > DATETIME('now');"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "UPDATE metadata_items SET added_at = DATETIME('now', '-1 days') WHERE DATETIME(originally_available_at) > DATETIME('now');"
echo "reown to $USER:$GROUP"
sudo chown "$USER:$GROUP" "${plexdbpath}"/*

# Start Applications
echo "start applications"
docker start "${plexdocker}"

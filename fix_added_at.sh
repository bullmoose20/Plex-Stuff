#!/bin/bash
# do not forget to determine what your library_section_id is for your plex libraries. mine were 1 (Movies), 9(TV Shows), 10(TestMovies), and 11(TestTV Shows)
# see this post for more details: https://www.reddit.com/r/PleX/comments/p8jj09/fix_added_date_based_on_file_modified_date/

sqplex="/mnt/user/data/scripts/plex-scripts/pumpanddump/plexsql/plexmediaserver/Plex Media Server"

function usage {
  echo ""
  echo "Usage: fix_added_at.sh plex "
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
# Get the current timestamp using the 'date' command in the format: YYYYMMDD_HHMMSS
timestamp=$(date +"%Y%m%d_%H%M%S")

# Copy the file and append the timestamp to the filename
cp com.plexapp.plugins.library.db "com.plexapp.plugins.library.db_$timestamp"

echo "cleaning/resetting folders"
rm -rf "/${dbp1}"/Codecs/*

echo "fix times"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "CREATE TEMP TABLE temp AS SELECT R.updated_at AS new_added_at, S.id FROM media_items R INNER JOIN metadata_items S ON R.metadata_item_id = S.id WHERE S.library_section_id = 1;SELECT * from temp;UPDATE metadata_items SET added_at = (SELECT new_added_at FROM temp WHERE temp.id=metadata_items.id); DROP TABLE temp;"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "CREATE TEMP TABLE temp AS SELECT R.updated_at AS new_added_at, S.id FROM media_items R INNER JOIN metadata_items S ON R.metadata_item_id = S.id WHERE S.library_section_id = 9;SELECT * from temp;UPDATE metadata_items SET added_at = (SELECT new_added_at FROM temp WHERE temp.id=metadata_items.id); DROP TABLE temp;"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "CREATE TEMP TABLE temp AS SELECT R.updated_at AS new_added_at, S.id FROM media_items R INNER JOIN metadata_items S ON R.metadata_item_id = S.id WHERE S.library_section_id = 10;SELECT * from temp;UPDATE metadata_items SET added_at = (SELECT new_added_at FROM temp WHERE temp.id=metadata_items.id); DROP TABLE temp;"
"${sqplex}" --sqlite com.plexapp.plugins.library.db "CREATE TEMP TABLE temp AS SELECT R.updated_at AS new_added_at, S.id FROM media_items R INNER JOIN metadata_items S ON R.metadata_item_id = S.id WHERE S.library_section_id = 11;SELECT * from temp;UPDATE metadata_items SET added_at = (SELECT new_added_at FROM temp WHERE temp.id=metadata_items.id); DROP TABLE temp;"

echo "reown to $USER:$GROUP"
sudo chown "$USER:$GROUP" "${plexdbpath}"/*

# Start Applications
echo "start applications"
docker start "${plexdocker}"

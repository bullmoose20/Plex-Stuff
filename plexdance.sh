#!/bin/bash

echo "This script will perform the PLEX Dance. Hit ctrl-c to cancel"
read -p "Press Enter to continue"
echo "Stopping containers that will NOT be restarted..."

containers_stop=("tdarr" "tdarr_node" "PIC" "POR" "TitleCardMaker" "Plex-Meta-Manager")
for container in "${containers_stop[@]}"
do
  docker stop "$container"
done

echo "Containers stopped"
echo "Stopping containers that will be restarted after plexdance completes..."

containers=("prowlarr" "radarr" "sonarr" "lidarr" "sabnzbd" "qbittorrent" "tautulli" "wrapperr" "PlexTraktSync")
for container in "${containers[@]}"
do
  docker stop "$container"
done

echo "Containers stopped"

directories=("music" "photos" "videos" "TestVideos" "movies" "tv" "testmovie" "testtv")

for directory in "${directories[@]}"
do
  chmod u+w "/mnt/user/data/media/${directory}/"
  mkdir -vp "/mnt/user/data/media/${directory}_dance/"
  mv "/mnt/user/data/media/${directory}/"* "/mnt/user/data/media/${directory}_dance/"
  mkdir -vp "/mnt/user/data/media/${directory}/fakedir"
done

echo "tv and movies moved"
echo "1 - Go scan libraries (may be done automatically by PLEX)"
echo "2 - Empty trash on libraries"
echo "3 - Clean Bundles on libraries"
echo "4 - Wait for all activities to complete!!!"
read -p "Press enter to continue to bring back all your media"

for directory in "${directories[@]}"
do
  mv "/mnt/user/data/media/${directory}_dance/"* "/mnt/user/data/media/${directory}/"
  rm -rf "/mnt/user/data/media/${directory}/fakedir"
done

echo "tv and movies returned to original location."
echo "1 - Go scan libraries again (may be done automatically by PLEX)"
echo "2 - Wait for all activities to complete!!!"
read -p "Press enter to continue to restart all your containers that were stopped"

for container in "${containers[@]}"
do
  docker start "$container"
done

echo "Containers restarted..."
echo "Optimize your DB"
echo "Plex Dance completed"

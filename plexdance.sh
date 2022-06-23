#!/bin/bash

echo "This script will perform the PLEX Dance. Hit ctrl-c to cancel"
read -p "Press Enter to continue"
echo "Stopping containers..."

  docker stop prowlarr
  docker stop radarr
  docker stop sonarr
  docker stop lidarr
  docker stop tdarr
  docker stop tdarr_node
  docker stop sabnzbd
  docker stop qbittorrent

echo "Containers stopped"
echo "Moving media now..."

  mkdir -p /mnt/user/data/media/movies_dance/
  mkdir -p /mnt/user/data/media/tv_dance/
  mkdir -p /mnt/user/data/media/testmovie_dance/
  mkdir -p /mnt/user/data/media/testtv_dance/

  mv /mnt/user/data/media/movies/* /mnt/user/data/media/movies_dance/
  mkdir -p /mnt/user/data/media/movies/fakedir
  mv /mnt/user/data/media/tv/* /mnt/user/data/media/tv_dance/
  mkdir -p /mnt/user/data/media/tv/fakedir

  mv /mnt/user/data/media/testmovie/* /mnt/user/data/media/testmovie_dance/
  mkdir -p /mnt/user/data/media/testmovie/fakedir
  mv /mnt/user/data/media/testtv/* /mnt/user/data/media/testtv_dance/
  mkdir -p /mnt/user/data/media/testtv/fakedir

echo "tv and movies moved"
echo "1 - Go scan libraries (may be done automatically by PLEX)"
echo "2 - Empty trash on libraries"
echo "3 - Clean Bundles on libraries"
echo "4 - Wait for all activities to complete!!!"
read -p "Press enter to continue to bring back all your media"

  mv /mnt/user/data/media/movies_dance/* /mnt/user/data/media/movies/
  rm -rf /mnt/user/data/media/movies/fakedir
  mv /mnt/user/data/media/tv_dance/* /mnt/user/data/media/tv/
  rm -rf /mnt/user/data/media/tv/fakedir

  mv /mnt/user/data/media/testmovie_dance/* /mnt/user/data/media/testmovie/
  rm -rf /mnt/user/data/media/testmovie/fakedir
  mv /mnt/user/data/media/testtv_dance/* /mnt/user/data/media/testtv/
  rm -rf /mnt/user/data/media/testtv/fakedir

echo "tv and movies returned to original location."
echo "1 - Go scan both libraries again (may be done automatically by PLEX)"
echo "2 - Wait for all activities to complete!!!"
read -p "Press enter to continue to restart all your containers that were stopped"

  docker start prowlarr
  docker start radarr
  docker start sonarr
  docker start lidarr
#  docker start tdarr
#  docker start tdarr_node
  docker start sabnzbd
  docker start qbittorrent

echo "Containers restarted..."
echo "Optimize your DB"
echo "Plex Dance completed"

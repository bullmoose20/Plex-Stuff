#!/bin/bash
echo "Restarting plex"
docker restart plex
echo "Sleeping 0 seconds"
sleep 0
echo "Running PBF"
../../venv/bin/python plex-bloat-fix.py


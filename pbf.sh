echo "Restarting plex"
docker restart plex
echo "Sleeping 30 seconds"
sleep 30
echo "Running PBF"
../../venv/bin/python plex-bloat-fix.py


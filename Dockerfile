FROM python:3.10-slim-buster
COPY plex-bloat-fix.py /
COPY requirements.txt /

RUN echo "**** setup ****" \
 && pip3 install --no-cache-dir --upgrade --requirement /requirements.txt \
 && rm -rf /requirements.txt /tmp/* /var/tmp/* /var/lib/apt/lists/*
 
ENTRYPOINT ["python3", "plex-bloat-fix.py"]

FROM node:20-slim

RUN npm install -g elasticdump
RUN apt-get update && apt-get install -y curl && rm -rf /var/lib/apt/lists/*

COPY load.sh /load.sh
RUN chmod +x /load.sh

ENTRYPOINT ["/load.sh"]

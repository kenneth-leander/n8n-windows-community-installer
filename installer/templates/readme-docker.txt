STARTING AND STOPPING n8n
----------------------------------------------------------------
n8n runs in a Docker container called "@@DOCKER_NAME@@". It starts again by
itself whenever Docker Desktop starts.

To start:  "Start n8n" in the Start menu (Docker Desktop must be running),
           or in a terminal:  docker start @@DOCKER_NAME@@
To stop:   "Stop n8n" in the Start menu, or:  docker stop @@DOCKER_NAME@@
Logs:      docker logs -f @@DOCKER_NAME@@

You can also manage the container in the Docker Desktop window.

The n8n image used:    @@IMAGE@@
Time zone:             @@TZ@@
Data volume:           @@DOCKER_VOLUME@@

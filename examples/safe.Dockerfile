FROM ubuntu:22.04
RUN apt-get update && apt-get install -y --no-install-recommends \
    nginx ca-certificates && rm -rf /var/lib/apt/lists/*
RUN useradd -r -u 1001 -s /bin/false nginxuser
USER nginxuser
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]


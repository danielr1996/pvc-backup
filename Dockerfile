FROM bitnami/kubectl:1.28.2 as kubectl
FROM restic/restic:0.16.0 as restic
FROM alpine
COPY --from=kubectl /opt/bitnami/kubectl/bin/kubectl /usr/bin/kubectl
COPY --from=restic /usr/bin/restic /usr/bin/restic
WORKDIR /app
ENV PATH=$PATH:/app
COPY container/backup.sh backup
COPY container/restore.sh restore
RUN chmod -R a+x .
ENTRYPOINT [ "backup" ]
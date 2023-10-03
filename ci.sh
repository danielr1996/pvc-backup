#! /bin/bash
docker buildx build --push --platform=linux/arm64 -t ghcr.io/danielr1996/pvc-backup:latest .
helm package chart -d dist
helm push dist/pvc-backup-chart-0.1.0.tgz oci://ghcr.io/danielr1996
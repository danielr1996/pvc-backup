# pvc-backup
backup kubernetes pvc to s3 storage using csi snapshots

> heavily inspired by https://alexlubbock.com/encrypted-backup-kubernetes-pvc-backblaze-b2

## Installation
```sh
helm upgrade --install  --create-namespace -n backup backup chart -f values.yaml 
```

## Usage

> The CronJob needs to be created in the namespace as the deployment to be able to mount the ServiceAccount

```sh
kubectl apply -f examples/cronjob.yaml -n <release-namespace>
```
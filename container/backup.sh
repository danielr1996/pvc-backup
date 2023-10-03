#!/bin/sh
export BUCKET=$(kubectl get secret -n $SECRETNAMESPACE $SECRETNAME -o jsonpath={.data.BUCKET} | base64 -d)
export RESTIC_PASSWORD=$(kubectl get secret -n $SECRETNAMESPACE $SECRETNAME -o jsonpath={.data.RESTIC_PASSWORD} | base64 -d)
export AWS_ACCESS_KEY_ID=$(kubectl get secret -n $SECRETNAMESPACE $SECRETNAME -o jsonpath={.data.AWS_ACCESS_KEY_ID} | base64 -d)
export AWS_SECRET_ACCESS_KEY=$(kubectl get secret -n $SECRETNAMESPACE $SECRETNAME -o jsonpath={.data.AWS_SECRET_ACCESS_KEY} | base64 -d)
export RESTIC_REPOSITORY="$BUCKET/$PVC"


restic cat config
if [[ "$?" -ne 0 ]]; then
    echo "restic repo doesn't exist, initializing"
    restic init
else 
    echo "repo exists"
fi

ID=$(LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 8)
SNAPSHOTNAME="$PVC-snapshot-$ID"
BACKUPPVCNAME="$PVC-backup-$ID"
BACKUPJOBNAME="$PVC-backup-job-$ID"

cat <<EOF | kubectl apply -f - 
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: "$SNAPSHOTNAME"
  namespace: "$NAMESPACE"
spec:
  source:
    persistentVolumeClaimName: "$PVC"
EOF

cat <<EOF | kubectl apply -f - 
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: "$BACKUPPVCNAME"
  namespace: "$NAMESPACE"
spec:
  dataSource:
    name: "$SNAPSHOTNAME"
    kind: VolumeSnapshot
    apiGroup: snapshot.storage.k8s.io
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: "$(kubectl get pvc -n $NAMESPACE -o jsonpath={.spec.resources.requests.storage} $PVC)"
EOF

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: "$BACKUPJOBNAME"
  namespace: "$NAMESPACE"
spec:
  ttlSecondsAfterFinished: 60
  template:
    spec:
      restartPolicy: Never
      containers:
        - name: restic
          image: restic/restic:latest
          workingDir: /data
          args:
            - backup
            - --host
            - kubernetes
            - .
          env:
            - name: RESTIC_REPOSITORY
              value: "$RESTIC_REPOSITORY"
            - name: AWS_ACCESS_KEY_ID
              value: "$AWS_ACCESS_KEY_ID"
            - name: AWS_SECRET_ACCESS_KEY
              value: "$AWS_SECRET_ACCESS_KEY"
            - name: RESTIC_PASSWORD
              value: "$RESTIC_PASSWORD"
          volumeMounts:
            - name: data
              mountPath: /data
              readOnly: true
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: "$BACKUPPVCNAME"
EOF
kubectl wait --for=condition=complete -n "$NAMESPACE" jobs/$BACKUPJOBNAME
echo "backup complete"
kubectl delete pvc -n "$NAMESPACE" "$BACKUPPVCNAME"
kubectl delete volumesnapshot -n "$NAMESPACE" "$SNAPSHOTNAME"
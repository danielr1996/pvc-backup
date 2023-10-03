#!/bin/sh
export BUCKET=$(kubectl get secret -n $SECRETNAMESPACE $SECRETNAME -o jsonpath={.data.BUCKET} | base64 -d)
export RESTIC_PASSWORD=$(kubectl get secret -n $SECRETNAMESPACE $SECRETNAME -o jsonpath={.data.RESTIC_PASSWORD} | base64 -d)
export AWS_ACCESS_KEY_ID=$(kubectl get secret -n $SECRETNAMESPACE $SECRETNAME -o jsonpath={.data.AWS_ACCESS_KEY_ID} | base64 -d)
export AWS_SECRET_ACCESS_KEY=$(kubectl get secret -n $SECRETNAMESPACE $SECRETNAME -o jsonpath={.data.AWS_SECRET_ACCESS_KEY} | base64 -d)
export RESTIC_REPOSITORY="$BUCKET/$PVC"

ID=$(LC_ALL=C tr -dc a-z0-9 </dev/urandom | head -c 8)
RESTOREJOBNAME="$PVC-backup-job-$ID"

cat <<EOF | kubectl apply -f -
apiVersion: batch/v1
kind: Job
metadata:
  name: "$RESTOREJOBNAME"
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
            - restore
            - latest
            - --target
            - /data
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
      volumes:
        - name: data
          persistentVolumeClaim:
            claimName: "$PVC"
EOF

kubectl wait --for=condition=complete -n "$NAMESPACE" jobs/$RESTOREJOBNAME
echo "restore complete"
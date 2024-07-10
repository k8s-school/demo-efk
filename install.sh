#!/bin/bash

set -euxo pipefail

# WARN does not work in dind
# see https://platform9.com/blog/kubernetes-logging-and-monitoring-the-elasticsearch-fluentd-and-kibana-efk-stack-part-2-elasticsearch-configuration/

DIR=$(cd "$(dirname "$0")"; pwd -P)

NS="logging"

kubectl delete ns -l name="logging"
kubectl create namespace "$NS"
kubectl label ns "$NS" name="logging"

# Deploy ECK
# https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-eck.html
kubectl apply -f https://download.elastic.co/downloads/eck/2.13.0/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.13.0/operator.yaml

kubectl -n elastic-system logs statefulset.apps/elastic-operator

# Work in logging namespace
kubectl config set-context $(kubectl config current-context) --namespace="$NS"

# Deploy Elasticsearch
# https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-elasticsearch.html
cat <<EOF | kubectl apply -f -
apiVersion: elasticsearch.k8s.elastic.co/v1
kind: Elasticsearch
metadata:
  name: quickstart
spec:
  version: 8.14.2
  nodeSets:
  - name: default
    count: 1
    config:
      node.store.allow_mmap: false
EOF

kubectl get elasticsearch
kubectl get pods --selector='elasticsearch.k8s.elastic.co/cluster-name=quickstart'

PASSWORD=$(kubectl get secret quickstart-es-elastic-user -o go-template='{{.data.elastic | base64decode}}')

# https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-deploy-kibana.html
cat <<EOF | kubectl apply -f -
apiVersion: kibana.k8s.elastic.co/v1
kind: Kibana
metadata:
  name: quickstart
spec:
  version: 8.14.2
  count: 1
  elasticsearchRef:
    name: quickstart
EOF

kubectl get kibana
kubectl get pod --selector='kibana.k8s.elastic.co/name=quickstart'

# https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-beat-quickstart.html
cat <<EOF | kubectl apply -f -
apiVersion: beat.k8s.elastic.co/v1beta1
kind: Beat
metadata:
  name: quickstart
spec:
  type: filebeat
  version: 8.14.2
  elasticsearchRef:
    name: quickstart
  config:
    filebeat.inputs:
    - type: container
      paths:
      - /var/log/containers/*.log
  daemonSet:
    podTemplate:
      spec:
        dnsPolicy: ClusterFirstWithHostNet
        hostNetwork: true
        securityContext:
          runAsUser: 0
        containers:
        - name: filebeat
          volumeMounts:
          - name: varlogcontainers
            mountPath: /var/log/containers
          - name: varlogpods
            mountPath: /var/log/pods
          - name: varlibdockercontainers
            mountPath: /var/lib/docker/containers
        volumes:
        - name: varlogcontainers
          hostPath:
            path: /var/log/containers
        - name: varlogpods
          hostPath:
            path: /var/log/pods
        - name: varlibdockercontainers
          hostPath:
            path: /var/lib/docker/containers
EOF

kubectl get beat
kubectl get pods --selector='beat.k8s.elastic.co/name=quickstart-beat-filebeat'

echo "Generate logs"
$DIR/generate-log.sh > /dev/null &

echo "Run port-forward to Kibana:"
echo "kubectl port-forward service/quickstart-kb-http 5601"
echo "Connect to Kibana on https://localhost:5601"
echo "login: elastic, password: $PASSWORD"
echo 'In Kibana, go to "Discover", add "filebeat-7.17.3*" index and "@timestamp" filter'
echo 'then go to "Discover" and search on "Connecting"'

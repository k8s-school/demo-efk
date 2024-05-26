helm repo add elastic https://helm.elastic.co
helm repo update
kubectl create -f https://download.elastic.co/downloads/eck/2.12.1/crds.yaml
kubectl apply -f https://download.elastic.co/downloads/eck/2.12.1/operator.yaml
# No fluentbit...
# helm install eck-stack-with-logstash elastic/eck-stack --values https://raw.githubusercontent.com/elastic/cloud-on-k8s/2.12/deploy/eck-stack/examples/logstash/basic-eck.yaml -n elastic-stack --create-namespace
# kubectl get elastic -n elastic-stack -l "app.kubernetes.io/instance"=eck-stack-with-logstash

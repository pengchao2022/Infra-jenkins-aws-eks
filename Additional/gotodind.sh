kubectl exec -n jenkins -it $(kubectl get pods -n jenkins -l app=jenkins-agent -o jsonpath='{.items[0].metadata.name}') -c dind -- sh

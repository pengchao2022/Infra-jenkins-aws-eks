# 获取 Master Pod 的实际 IP
MASTER_POD_IP=$(kubectl get pod -n jenkins jenkins-master-84c8d49974-tlm7b -o jsonpath='{.status.podIP}')
echo "Master Pod IP: $MASTER_POD_IP"

# 从 Agent 直接连接 Pod IP（完全绕过 Service 和 DNS）
kubectl exec -n jenkins -it $(kubectl get pods -n jenkins -l app=jenkins-agent -o jsonpath='{.items[0].metadata.name}') -c jnlp -- wget -T 10 -O- http://${MASTER_POD_IP}:8080

# 获取 Master Pod 的实际 IP
MASTER_POD_IP=$(kubectl get pod -n jenkins jenkins-master-84c8d49974-tlm7b -o jsonpath='{.status.podIP}')
echo "Master Pod IP: $MASTER_POD_IP"

# 测试直接 Pod IP 连接
kubectl exec -n jenkins -it $(kubectl get pods -n jenkins -l app=jenkins-agent -o jsonpath='{.items[0].metadata.name}') -c jnlp -- sh -c "
echo '=== 测试直接 Pod IP 连接 ==='
wget -O- http://${MASTER_POD_IP}:8080 --timeout=10 || echo '直接 Pod IP 连接也失败'
"

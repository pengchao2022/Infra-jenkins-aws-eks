# 删除当前 Agent
kubectl delete deployment jenkins-agent -n jenkins

# 使用 Pod IP 创建 Agent（绕过 Service 问题）
MASTER_POD_IP=$(kubectl get pod -n jenkins jenkins-master-84c8d49974-tlm7b -o jsonpath='{.status.podIP}')

kubectl apply -f - <<EOF
apiVersion: apps/v1
kind: Deployment
metadata:
  name: jenkins-agent
  namespace: jenkins
spec:
  replicas: 1
  selector:
    matchLabels:
      app: jenkins-agent
  template:
    metadata:
      labels:
        app: jenkins-agent
    spec:
      serviceAccountName: jenkins
      containers:
      - name: jnlp
        image: jenkins/inbound-agent:latest
        command:
        - /bin/sh
        - -c
        - |
          echo "=== 使用 Pod IP 连接 Jenkins Master ==="
          echo "Master Pod IP: ${MASTER_POD_IP}"
          
          # 使用 Pod IP 直接连接
          exec java -jar /usr/share/jenkins/agent.jar \
            -url http://${MASTER_POD_IP}:8080 \
            -workDir /home/jenkins/agent \
            -secret "\$JENKINS_AGENT_SECRET" \
            -name kubernetes-agent
        env:
        - name: JENKINS_AGENT_SECRET
          valueFrom:
            secretKeyRef:
              name: jenkins-agent-secret
              key: secret
        volumeMounts:
        - name: workspace
          mountPath: /home/jenkins/agent
      volumes:
      - name: workspace
        emptyDir: {}
EOF

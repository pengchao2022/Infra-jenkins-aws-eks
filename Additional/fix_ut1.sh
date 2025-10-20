#!/bin/bash

# 删除当前 Agent
kubectl delete deployment jenkins-agent -n jenkins

# 创建使用正确端口的 Agent
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
        securityContext:
          runAsUser: 0
        command:
        - /bin/sh
        - -c
        - |
          echo "=== 安装所有必要工具 ==="
          apt-get update
          apt-get install -y curl unzip python3 python3-pip
          
          # 安装 AWS CLI
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip -q awscliv2.zip
          ./aws/install --bin-dir /usr/local/bin
          rm -rf awscliv2.zip aws/
          
          # 安装 Docker CLI
          curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-20.10.9.tgz | tar -xzC /usr/local/bin --strip-components=1
          
          echo "=== 等待 Docker Daemon 启动 ==="
          counter=0
          while [ \$counter -lt 60 ]; do
            if docker version >/dev/null 2>&1; then
              echo "✅ Docker daemon 就绪"
              break
            fi
            echo "等待 Docker daemon... (\$((counter+1))/60)"
            sleep 2
            counter=\$((counter+1))
          done
          
          echo "=== 启动 Jenkins Agent ==="
          # 使用正确的端口 80
          exec java -jar /usr/share/jenkins/agent.jar \\
               -url http://jenkins-master.jenkins:80 \\
               -workDir /home/jenkins/agent \\
               -secret "\$JENKINS_AGENT_SECRET" \\
               -name kubernetes-agent \\
               -webSocket
        env:
        - name: DOCKER_HOST
          value: unix:///var/run/docker.sock
        - name: JENKINS_AGENT_SECRET
          valueFrom:
            secretKeyRef:
              name: jenkins-agent-secret
              key: secret
        volumeMounts:
        - name: workspace
          mountPath: /home/jenkins/agent
        - name: docker-socket
          mountPath: /var/run
      - name: dind
        image: docker:dind
        securityContext:
          privileged: true
        args:
        - --storage-driver=overlay2
        volumeMounts:
        - name: docker-storage
          mountPath: /var/lib/docker
        - name: docker-socket
          mountPath: /var/run
      volumes:
      - name: workspace
        emptyDir: {}
      - name: docker-socket
        emptyDir: {}
      - name: docker-storage
        emptyDir: {}
EOF

echo "Jenkins Agent 已重新部署，使用正确的端口 80"

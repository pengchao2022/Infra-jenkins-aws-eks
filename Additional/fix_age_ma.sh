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
          echo "=== 安装基础工具 ==="
          apt-get update && apt-get install -y curl unzip python3
          
          echo "=== 安装 AWS CLI ==="
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip -q awscliv2.zip
          ./aws/install --bin-dir /usr/local/bin
          rm -rf awscliv2.zip aws/
          
          echo "=== 安装 Docker CLI ==="
          curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-20.10.9.tgz | tar -xzC /usr/local/bin --strip-components=1
          
          echo "=== 等待 Docker Daemon 启动 ==="
          for i in {1..30}; do
            if docker version >/dev/null 2>&1; then
              echo "✅ Docker daemon 就绪"
              break
            fi
            sleep 2
          done
          
          echo "=== 启动 Jenkins Agent ==="
          # 正确的参数格式：使用 -url 和 -secret，不要用 -jnlpUrl
          exec java -jar /usr/share/jenkins/agent.jar \
            -url http://jenkins-master.jenkins:8080 \
            -workDir /home/jenkins/agent \
            -secret "\$JENKINS_AGENT_SECRET" \
            -name kubernetes-agent
        env:
        - name: DOCKER_HOST
          value: "unix:///var/run/docker.sock"
        - name: JENKINS_AGENT_SECRET
          valueFrom:
            secretKeyRef:
              name: jenkins-agent-secret
              key: secret
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "200m"
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
        resources:
          requests:
            memory: "256Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "200m"
        volumeMounts:
        - name: docker-socket
          mountPath: /var/run
        - name: docker-storage
          mountPath: /var/lib/docker

      volumes:
      - name: workspace
        emptyDir: {}
      - name: docker-socket
        emptyDir: {}
      - name: docker-storage
        emptyDir: {}
EOF

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
          curl -fsSL https://download.docker.com/linux/static/stable/x86_64/docker-20.10.9.tgz | tar -xzC /usr/local/bin --strip-components=1
          curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
          unzip -q awscliv2.zip
          ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
          rm -rf awscliv2.zip aws/
          
          echo "=== 等待 Docker Daemon 启动 ==="
          for i in {1..30}; do
            if docker version >/dev/null 2>&1; then
              echo "Docker daemon 就绪"
              break
            fi
            sleep 2
          done
          
          echo "=== 测试网络连接 ==="
          # 测试 Service 端口 80
          wget -O- http://jenkins-master.jenkins:80 || echo "Service port 80 连接失败"
          # 测试直接 Pod 端口 8080  
          wget -O- http://jenkins-master.jenkins:8080 || echo "Direct port 8080 连接失败"
          
          echo "=== 启动 Jenkins Agent ==="
          # 使用 Service 端口 80
          exec java -jar /usr/share/jenkins/agent.jar \
            -url http://jenkins-master.jenkins:80 \
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
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "400m"
        volumeMounts:
        - name: workspace
          mountPath: /home/jenkins/agent
        - name: docker-sock
          mountPath: /var/run/docker.sock
      - name: dind
        image: docker:dind
        securityContext:
          privileged: true
        args:
        - --storage-driver=overlay2
        - --host=unix:///var/run/docker.sock
        env:
        - name: DOCKER_TLS_CERTDIR
          value: ""
        resources:
          requests:
            memory: "256Mi"
            cpu: "200m"
          limits:
            memory: "512Mi"
            cpu: "400m"
        volumeMounts:
        - name: docker-sock
          mountPath: /var/run
        - name: docker-lib
          mountPath: /var/lib/docker
      volumes:
      - name: workspace
        emptyDir: {}
      - name: docker-sock
        emptyDir: {}
      - name: docker-lib
        emptyDir: {}
EOF

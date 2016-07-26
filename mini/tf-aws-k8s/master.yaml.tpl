#cloud-config

---
write-files:
  - path: /etc/conf.d/nfs
    permissions: '0644'
    content: |
      OPTS_RPC_MOUNTD=""
  - path: /root/.credentials
    permissions: 0644
    content: |
      ${usertoken},${user},${user}
      kubelet,kubelet,kubelet
      scheduler,scheduler,scheduler
      pong,ping,health
  - path: /opt/auth-policy.jsonl
    permissions : 0644
    content: |
      {"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"*", "nonResourcePath": "/healthz", "readonly": true}}
      {"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"admin", "namespace": "*", "resource": "*", "apiGroup": "*",  "nonResourcePath":"*"}}
      {"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"scheduler", "namespace": "*", "resource": "*", "apiGroup": "*", "nonResourcePath": "*"}}
      {"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"user":"kubelet", "namespace": "*", "resource": "*", "apiGroup": "*", "nonResourcePath": "*"}}
      {"apiVersion": "abac.authorization.kubernetes.io/v1beta1", "kind": "Policy", "spec": {"group":"system:serviceaccounts", "namespace": "*", "resource": "*", "apiGroup": "*", "nonResourcePath": "*"}}
  - path: /opt/bin/wupiao
    permissions: '0755'
    content: |
      #!/bin/bash
      # [w]ait [u]ntil [p]ort [i]s [a]ctually [o]pen
      [ -n "$1" ] && \
        until curl -o /dev/null -sIf http://$${1}; do \
          sleep 1 && echo .;
        done;
      exit $?

coreos:
  etcd2:
    listen-client-urls: http://0.0.0.0:2379
    advertise-client-urls: http://$private_ipv4:2379
    discovery: ${discovery_token}
    listen-peer-urls: http://$private_ipv4:2380
    initial-advertise-peer-urls: http://$private_ipv4:2380
  fleet:
    metadata: "role=master"
  flannel:
      etcd_endpoints: "http://master0.${clustername}.aws.internal:2379,http://master1.${clustername}.aws.internal:2379,http://master2.${clustername}.aws.internal:2379"
  units:
    - name: etcd2.service
      command: start
    - name: generate-serviceaccount-key.service
      command: start
      content: |
        [Unit]
        Description=Generate service-account key file

        [Service]
        ExecStartPre=-/usr/bin/mkdir -p /opt/bin
        ExecStart=/bin/openssl genrsa -out /opt/bin/kube-serviceaccount.key 2048 2>/dev/null
        RemainAfterExit=yes
        Type=oneshot
    - name: setup-network-environment.service
      command: start
      content: |
        [Unit]
        Description=Setup Network Environment
        Documentation=https://github.com/kelseyhightower/setup-network-environment
        Requires=network-online.target
        After=network-online.target

        [Service]
        ExecStartPre=-/usr/bin/mkdir -p /opt/bin
        ExecStartPre=/usr/bin/curl -L -o /opt/bin/setup-network-environment -z /opt/bin/setup-network-environment https://github.com/kelseyhightower/setup-network-environment/releases/download/v1.0.0/setup-network-environment
        ExecStartPre=/usr/bin/chmod +x /opt/bin/setup-network-environment
        ExecStart=/opt/bin/setup-network-environment
        RemainAfterExit=yes
        Type=oneshot
    - name: flanneld.service
      command: start
      drop-ins:
        - name: 50-network-config.conf
          content: |
            [Unit]
            Requires=etcd2.service
            [Service]
            ExecStartPre=/usr/bin/etcdctl set /coreos.com/network/config '{"Network":"10.192.0.0/16", "Backend": {"Type": "vxlan"}}'
    - name: docker.service
      command: start
    - name: kube-apiserver.service
      command: start
      content: |
        [Unit]
        Description=Kubernetes API Server
        Documentation=https://github.com/kubernetes/kubernetes
        Requires=setup-network-environment.service etcd2.service generate-serviceaccount-key.service
        After=setup-network-environment.service etcd2.service generate-serviceaccount-key.service

        [Service]
        EnvironmentFile=/etc/network-environment
        ExecStartPre=-/usr/bin/mkdir -p /opt/bin
        ExecStartPre=/usr/bin/curl -L -o /opt/bin/kube-apiserver -z /opt/bin/kube-apiserver https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-apiserver
        ExecStartPre=/usr/bin/chmod +x /opt/bin/kube-apiserver
        ExecStartPre=/opt/bin/wupiao master0.${clustername}.aws.internal:2379/v2/machines
        ExecStart=/opt/bin/kube-apiserver \
        --service-account-key-file=/opt/bin/kube-serviceaccount.key \
        --service-account-lookup=false \
        --admission-control=NamespaceLifecycle,NamespaceAutoProvision,LimitRanger,SecurityContextDeny,ServiceAccount,ResourceQuota \
        --runtime-config=api/v1 \
        --allow-privileged=true \
        --insecure-bind-address=0.0.0.0 \
        --bind-address=0.0.0.0 \
        --insecure-port=8080 \
        --kubelet-https=true \
        --secure-port=6443 \
        --service-cluster-ip-range=10.100.0.0/16 \
        --etcd-servers=http://master0.${clustername}.aws.internal:2379,http://master1.${clustername}.aws.internal:2379,http://master2.${clustername}.aws.internal:2379 \
        --public-address-override=$${DEFAULT_IPV4} \
        --apiserver-count=3 \
        --cloud-provider=aws \
        --logtostderr=true
        Restart=always
        RestartSec=10
    - name: kube-controller-manager.service
      command: start
      content: |
        [Unit]
        Description=Kubernetes Controller Manager
        Documentation=https://github.com/kubernetes/kubernetes
        Requires=kube-apiserver.service
        After=kube-apiserver.service

        [Service]
        EnvironmentFile=/etc/network-environment
        ExecStartPre=/usr/bin/curl -L -o /opt/bin/kube-controller-manager -z /opt/bin/kube-controller-manager https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-controller-manager
        ExecStartPre=/usr/bin/chmod +x /opt/bin/kube-controller-manager
        ExecStart=/opt/bin/kube-controller-manager \
          --service-account-private-key-file=/opt/bin/kube-serviceaccount.key \
          --cloud-provider=aws \
          --logtostderr=true \
          --master=$${DEFAULT_IPV4}:8080 \
          --leader-elect=true \
          --v=2
        Restart=always
        RestartSec=10
    - name: kube-scheduler.service
      command: start
      content: |
        [Unit]
        Description=Kubernetes Scheduler
        Documentation=https://github.com/kubernetes/kubernetes
        Requires=kube-apiserver.service
        After=kube-apiserver.service

        [Service]
        EnvironmentFile=/etc/network-environment
        ExecStartPre=/usr/bin/curl -L -o /opt/bin/kube-scheduler -z /opt/bin/kube-scheduler https://storage.googleapis.com/kubernetes-release/release/v1.3.0/bin/linux/amd64/kube-scheduler
        ExecStartPre=/usr/bin/chmod +x /opt/bin/kube-scheduler
        ExecStart=/opt/bin/kube-scheduler \
          --master=$${DEFAULT_IPV4}:8080 \
          --leader-elect=true \
          --v=2
  update:
    group: alpha
    reboot-strategy: off

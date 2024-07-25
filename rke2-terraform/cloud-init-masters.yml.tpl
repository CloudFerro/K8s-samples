#cloud-config
packages:
  - iptables
  - apparmor-parser
ssh_authorized_keys:
- "${public_key}"
write_files:
- path: /etc/NetworkManager/conf.d
  permissions: "0755"
  owner: root:root
  content: |
    [keyfile]
    unmanaged-devices=interface-name:cali*;interface-name:flannel*
- path: /usr/local/bin/install-rke2.sh
  permissions: "0755"
  owner: root:root
  content: |
    #!/bin/sh
    # Install RKE2

    curl -sfL https://get.rke2.io | sh -

    # Enable and start RKE2 server service
    systemctl enable rke2-server.service
    systemctl start rke2-server.service
- path: /home/eouser/wait-for-masters.sh
  permissions: "0755"
  owner: root:root
  content: |
    #!/bin/bash

    KUBECONFIG_PATH=/etc/rancher/rke2/rke2.yaml

    function check_all_masters_ready {
      KUBECONFIG=/etc/rancher/rke2/rke2.yaml /var/lib/rancher/rke2/bin/kubectl get nodes -l node-role.kubernetes.io/master --no-headers | awk '{print $2}' | grep -v '^Ready$' > /dev/null
      return $?
    }

    while [ ! -f /etc/rancher/rke2/rke2-remote.yaml ] || [ ! check_all_masters_ready ]; do
      echo "Waiting for masters and kubeconfig ..."
      sleep 10
    done

    echo "All master nodes are ready!"
- path: /etc/rancher/rke2/config.yaml
  permissions: "0600"
  owner: root:root
  content: |
    token: "${rke2_token}"
    write-kubeconfig-mode: "0640"
    tls-san: "${public_address}"
    disable-cloud-controller: True
- path: /var/lib/rancher/rke2/server/manifests/rke2-openstack-cloud-controller-manager.yaml
  permissions: "0600"
  owner: root:root
  content: |
    apiVersion: helm.cattle.io/v1
    kind: HelmChart
    metadata:
      name: openstack-cloud-controller-manager
      namespace: kube-system
    spec:
      chart: openstack-cloud-controller-manager
      repo: https://kubernetes.github.io/cloud-provider-openstack
      targetNamespace: kube-system
      bootstrap: True
      valuesContent: |-
        nodeSelector:
          node-role.kubernetes.io/control-plane: "true"
        cloudConfig:
          global:
            auth-url: https://keystone.cloudferro.com:5000
            application-credential-id: "${application_credential_id}"
            application-credential-secret: "${application_credential_secret}"
            region: ${region}
            tenant-id: ${project_id}
          loadBalancer:
            floating-network-id: "${floating_network_id}"
            subnet-id: ${subnet_id}
runcmd:
  - /usr/local/bin/install-rke2.sh
  - [ sh, -c, 'until [ -f /etc/rancher/rke2/rke2.yaml ]; do echo Waiting for rke2 to start && sleep 10; done;' ]
  - cp /etc/rancher/rke2/rke2.yaml /etc/rancher/rke2/rke2-remote.yaml
  - sudo chgrp eouser /etc/rancher/rke2/rke2-remote.yaml
  - KUBECONFIG=/etc/rancher/rke2/rke2-remote.yaml /var/lib/rancher/rke2/bin/kubectl config set-cluster default --server https://${public_address}:6443
  - KUBECONFIG=/etc/rancher/rke2/rke2-remote.yaml /var/lib/rancher/rke2/bin/kubectl config rename-context default ${cluster_name}
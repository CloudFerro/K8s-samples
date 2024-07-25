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
- path: /usr/local/bin/install-rke2-agent.sh
  permissions: "0755"
  owner: root:root
  content: |
    #!/bin/sh

    curl -sfL https://get.rke2.io | INSTALL_RKE2_TYPE="agent" sh -

    # Enable and start RKE2 agent service
    systemctl enable rke2-agent.service
    systemctl start rke2-agent.service

- path: /etc/rancher/rke2/config.yaml
  permissions: "0600"
  owner: root:root
  content: |
    token: "${rke2_token}"
    server: "https://${public_address}:9345"

runcmd:
  - /usr/local/bin/install-rke2-agent.sh
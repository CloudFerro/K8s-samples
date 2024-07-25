locals {

  # https://docs.rke2.io/install/requirements#inbound-network-rules
  # Security groups should be further tuned for production
  # Canal CNI combines Flannel for networking pod traffic between hosts and Calico for network policy enforcement and pod to pod traffic
  # https://kops.sigs.k8s.io/networking/canal/

  masters_rules = [

      { "source" = "0.0.0.0/0", "protocol" = "tcp", "port_range_min" = 9345, "port_range_max" = 9345, "desc" = "Register new nodes" },
      { "source" = "0.0.0.0/0", "protocol" = "tcp", "port_range_min" = 6443, "port_range_max" = 6443, "desc" = "Kubernetes API" },
      { "source" = "0.0.0.0/0", "protocol" = "udp", "port_range_min" = 8472, "port_range_max" = 8472, "desc" = "Canal CNI with VXLAN" },
      { "source" = "0.0.0.0/0", "protocol" = "tcp", "port_range_min" = 10250, "port_range_max" = 10250, "desc" = "kubelet metrics" },
      { "source" = "0.0.0.0/0", "protocol" = "udp", "port_range_min" = 9099, "port_range_max" = 9099, "desc" = "Canal CNI health checks" },
      { "source" = "0.0.0.0/0", "protocol" = "tcp", "port_range_min" = 2379, "port_range_max" = 2379, "desc" = "etcd client requests" },
      { "source" = "0.0.0.0/0", "protocol" = "tcp", "port_range_min" = 2380, "port_range_max" = 2380, "desc" = "etcd server to server" },

      { "source" = "0.0.0.0/0", "protocol" = "tcp", "port_range_min" = 22, "port_range_max" = 22, "desc" = "SSH" },
      { "source" = "0.0.0.0/0", "protocol" = "tcp", "port_range_min" = 53, "port_range_max" = 53, "desc" = "DNS" },
      { "source" = "0.0.0.0/0", "protocol" = "tcp", "port_range_min" = 179, "port_range_max" = 179, "desc" = "BGP" },  

      { "source" = "0.0.0.0/0", "protocol" = "tcp", "port_range_min" = 30000, "port_range_max" = 32767, "desc" = "Nodeport port range" }
    ]

  workers_rules = [
      { "source" = "0.0.0.0/0", "protocol" = "udp", "port_range_min" = 8472, "port_range_max" = 8472, "desc" = "Canal CNI with VXLAN" },
      { "source" = "0.0.0.0/0", "protocol" = "tcp", "port_range_min" = 10250, "port_range_max" = 10250, "desc" = "kubelet metrics" },
      
      { "source" = "0.0.0.0/0", "protocol" = "tcp", "port_range_min" = 22, "port_range_max" = 22, "desc" = "SSH" },

      { "source" = "0.0.0.0/0", "protocol" = "tcp", "port_range_min" = 30000, "port_range_max" = 32767, "desc" = "Nodeport port range" }

    ]
}

# Masters security group
resource "openstack_networking_secgroup_v2" "masters_secgroup" {
  name        = "rke2-secgroup-masters"
  description = "Security group for RKE2 master nodes"
}

# Workers security group
resource "openstack_networking_secgroup_v2" "workers_secgroup" {
  name        = "rke2-secgroup-workers"
  description = "Security group for RKE2 worker nodes"
}

# Security group rule - Accept traffic from masters to masters
resource "openstack_networking_secgroup_rule_v2" "masters_allow_masters" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.masters_secgroup.id
  security_group_id = openstack_networking_secgroup_v2.masters_secgroup.id
}

# Security group rule - Accept traffic from workers to masters
resource "openstack_networking_secgroup_rule_v2" "masters_allow_workers" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.workers_secgroup.id
  security_group_id = openstack_networking_secgroup_v2.masters_secgroup.id
}

# Security group rule - Accept traffic from workers to workers
resource "openstack_networking_secgroup_rule_v2" "workers_allow_workers" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.workers_secgroup.id
  security_group_id = openstack_networking_secgroup_v2.workers_secgroup.id
}

# Security group rule - Accept traffic from masters to workers
resource "openstack_networking_secgroup_rule_v2" "workers_allow_masters" {
  direction         = "ingress"
  ethertype         = "IPv4"
  remote_group_id   = openstack_networking_secgroup_v2.masters_secgroup.id
  security_group_id = openstack_networking_secgroup_v2.workers_secgroup.id
}

# Specific rules for Kubernetes masters
resource "openstack_networking_secgroup_rule_v2" "masters_rules" {
  for_each = {
    for rule in local.masters_rules :
    format("%s-%s-%s-%s", rule["source"], rule["protocol"], rule["port_range_min"], rule["port_range_max"]) => rule
  }
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = each.value.protocol
  port_range_min    = each.value.port_range_min
  port_range_max    = each.value.port_range_max
  remote_ip_prefix  = each.value.source
  security_group_id = openstack_networking_secgroup_v2.masters_secgroup.id
}

# Specific rules for Kubernetes workers
resource "openstack_networking_secgroup_rule_v2" "workers_rules" {
  for_each = {
    for rule in local.workers_rules :
    format("%s-%s-%s-%s", rule["source"], rule["protocol"], rule["port_range_min"], rule["port_range_max"]) => rule
  }
  direction         = "ingress"
  ethertype         = "IPv4"
  protocol          = each.value.protocol
  port_range_min    = each.value.port_range_min
  port_range_max    = each.value.port_range_max
  remote_ip_prefix  = each.value.source
  security_group_id = openstack_networking_secgroup_v2.workers_secgroup.id
}
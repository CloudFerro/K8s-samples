# Create network
resource "openstack_networking_network_v2" "rke2_net" {
  name           = "rke2"
  admin_state_up = "true"
}

# Create subnet
resource "openstack_networking_subnet_v2" "rke2_subnet" {
    name       = "rke2"
    network_id = openstack_networking_network_v2.rke2_net.id
    cidr       = "10.0.0.0/24"
    ip_version = 4
}

# Reference existing external network, to retrieve its ID in later step
data "openstack_networking_network_v2" "public_net" {
  name = "external"
}

# Router
resource "openstack_networking_router_v2" "rke2_router" {
  name    = "rke2-router"
  external_network_id = data.openstack_networking_network_v2.public_net.id
}

# Router interface
resource "openstack_networking_router_interface_v2" "rke2_router_interface" {
  router_id = openstack_networking_router_v2.rke2_router.id
  subnet_id = openstack_networking_subnet_v2.rke2_subnet.id
}

# Keypair is already copied from main project when creating new project in Horizon
# resource "openstack_compute_keypair_v2" "keypair" {
#   name       = var.ssh_keypair_name
#   public_key = file("~/.ssh/id_rsa.pub")
# }

# Masters - Instances
resource "openstack_compute_instance_v2" "masters_instance" {
  count = var.masters_count
  name         = "${var.cluster_name}-master-${format("%03d", count.index + 1)}"
  image_name      = var.vm_image
  flavor_name       = var.masters_flavor
  key_pair        = var.ssh_keypair_name
  network {
    port = openstack_networking_port_v2.masters_port[count.index].id
  }
  user_data = base64encode(templatefile(("./cloud-init-masters.yml.tpl"), {
    cluster_name                  = var.cluster_name
    rke2_token                    = random_string.rke2_token.result
    public_address                = openstack_networking_floatingip_v2.master_fip.address
    subnet_id                     = openstack_networking_subnet_v2.rke2_subnet.id
    floating_network_id           = data.openstack_networking_network_v2.public_net.id
    project_id                    = var.project_id
    region                        = var.region
    public_key                    = var.public_key
    application_credential_id     = var.application_credential_id
    application_credential_secret = var.application_credential_secret 
  }))
}

# Workers - Instances
resource "openstack_compute_instance_v2" "workers_instance" {
  count = var.workers_count
  name         = "${var.cluster_name}-worker-${format("%03d", count.index + 1)}"
  image_name      = var.vm_image
  flavor_name       = var.workers_flavor
  key_pair        = var.ssh_keypair_name
  network {
    port = openstack_networking_port_v2.workers_port[count.index].id
  }
  user_data = base64encode(templatefile(("./cloud-init-workers.yml.tpl"), {
    cluster_name              = var.cluster_name
    rke2_token                = random_string.rke2_token.result
    public_address            = openstack_networking_floatingip_v2.master_fip.address
    public_key                = var.public_key
  }))
}

# Workers - Ports
resource "openstack_networking_port_v2" "workers_port" {
  count              = var.workers_count
  network_id         = openstack_networking_network_v2.rke2_net.id
  security_group_ids = [openstack_networking_secgroup_v2.workers_secgroup.id]
  admin_state_up     = true
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.rke2_subnet.id
  }
}

# Masters - Ports
resource "openstack_networking_port_v2" "masters_port" {
  count              = var.masters_count
  network_id         = openstack_networking_network_v2.rke2_net.id
  security_group_ids = [openstack_networking_secgroup_v2.masters_secgroup.id]
  admin_state_up     = true
  fixed_ip {
    subnet_id = openstack_networking_subnet_v2.rke2_subnet.id
  }
}

# Master - floating IP
resource "openstack_networking_floatingip_v2" "master_fip" {
  pool = "external"
}

# Master - floating IP association with VM
resource "openstack_networking_floatingip_associate_v2" "fip_associate" {
  count = var.masters_count
  floating_ip = openstack_networking_floatingip_v2.master_fip.address
  port_id       = openstack_networking_port_v2.masters_port[count.index].id
}

# Random string as token
resource "random_string" "rke2_token" {
  length = 64
}

# Wait to add FIP to Kubeconfig and master nodes to come up
resource "null_resource" "wait_for_masters" {
  provisioner "remote-exec" {
    inline = [
      "bash /home/eouser/wait-for-masters.sh"
    ]
    connection {
      type        = "ssh"
      user        = "eouser"
      private_key = file("~/.ssh/id_rsa")
      host        = openstack_networking_floatingip_v2.master_fip.address
    }
  }
  depends_on = [openstack_compute_instance_v2.masters_instance]
}

# Copy kubeconfig from remote to local
resource "null_resource" "copy_kubeconfig" {
  provisioner "local-exec" {
    command = "scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i ~/.ssh/id_rsa eouser@${openstack_networking_floatingip_v2.master_fip.address}:/etc/rancher/rke2/rke2-remote.yaml ./kubeconfig.yaml"
  }
  depends_on = [null_resource.wait_for_masters]
}
# Reference OpenStack provider
terraform {
required_version = ">= 0.14.0"
  required_providers {
    openstack = {
      source  = "terraform-provider-openstack/openstack"
      version = "~> 1.35.0"
    }
  }
}

# Configure OpenStack provider
provider "openstack" {
  auth_url =  "https://keystone.cloudferro.com:5000/v3"
}
variable "region" {
  type = string
  default = "WAW3-2"
  description = "CloudFerro cloud region"
}

variable "cluster_name" {
  type        = string
  default     = "samplecluster"
  description = "Cluster name"
}

# HA is not supported currently, keep 1 master node
variable "masters_count" {
  type        = number
  default     = 1
  description = "Number of master nodes (servers)"
}

variable "workers_count" {
  type        = number
  default     = 1
  description = "Number of worker nodes (agents)"
}

variable "masters_flavor" {
  type        = string
  default     = "eo1.large"
  description = "Master nodes VM flavor"
}

variable "workers_flavor" {
  type        = string
  default     = "eo1.large"
  description = "Worker nodes VM flavor"
}

variable "vm_image" {
  type        = string
  default     = "Ubuntu 22.04 LTS"
  description = "Operating system image for both masters and workers (tested only on Ubuntu 22.04 LTS image)"
}

variable "ssh_keypair_name" {
  type        = string
  description = "SSH keypair name"
}

variable "project_id" {
  type        = string
  description = "OpenStack project ID"
}

variable "public_key" {
  type        = string
  description = "Public key of the keypair in OpenStack"
}

variable "application_credential_id" {
  type = string
  description = "OpenStack application credential ID"
}

variable "application_credential_secret" {
  type = string
  description = "OpenStack application credential secret"
}
variable "cluster_name" {
  type        = string
  default     = "samplecluster"
  description = "Cluster name"
}

variable "ssh_keypair_name" {
  type        = string
  default     = "2468"
  description = "SSH keypair name"
}

variable "workers_count" {
  type        = number
  default     = 1
  description = "Number of worker nodes (agents)"
}

variable "masters_count" {
  type        = number
  default     = 1
  description = "Number of master nodes (servers)"
}

variable "project_id" {
  type        = string
  description = "OpenStack project ID"
}

variable "region" {
  type = string
  default = "WAW3-2"
  description = "CloudFerro cloud region"
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
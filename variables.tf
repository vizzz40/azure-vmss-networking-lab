variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
  default     = "project-1"
}

variable "location" {
  description = "Azure region where resources will be created"
  type        = string
  default     = "italynorth"
}

variable "vnet_address_space" {
  description = "Address space for the Virtual Network"
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_address_prefix" {
  description = "Address prefix for the VMSS subnet"
  type        = list(string)
  default     = ["10.0.0.0/20"]
}

variable "admin_source_cidr" {
  description = "Trusted administrator CIDR allowed to reach SSH through the Load Balancer NAT rule"
  type        = string

  validation {
    condition     = can(cidrhost(var.admin_source_cidr, 0))
    error_message = "admin_source_cidr must be a valid IPv4 or IPv6 CIDR block. Use a /32 for one IPv4 address."
  }
}

variable "ssh_public_key" {
  description = "OpenSSH public key installed for the azureuser account"
  type        = string

  validation {
    condition     = can(regex("^ssh-(rsa|ed25519|ecdsa)", trimspace(var.ssh_public_key)))
    error_message = "ssh_public_key must be a valid OpenSSH-format public key."
  }
}

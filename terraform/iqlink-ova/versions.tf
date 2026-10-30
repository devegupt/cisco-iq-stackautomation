terraform {
  required_version = ">= 1.5"
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = ">= 2.6"
    }
  }
}

# Credentials come from the Stack Automation vCenter target, which injects
# VSPHERE_SERVER / VSPHERE_USER / VSPHERE_PASSWORD (read by the provider).
provider "vsphere" {
  allow_unverified_ssl = var.allow_unverified_ssl
}

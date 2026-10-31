terraform {
  required_version = ">= 1.5, < 2.0"
  required_providers {
    vsphere = {
      source  = "hashicorp/vsphere"
      version = "~> 2.6"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.3"
    }
  }
}

# Stack Automation's vCenter Provider stores a full URL (the form requires https://) and passes it
# unchanged in VSPHERE_SERVER. The vSphere provider expects a hostname, so normalise it here.
# User and password still come from VSPHERE_USER / VSPHERE_PASSWORD injected by the target.
data "external" "vcenter" {
  program = ["sh", "${path.module}/vsphere-host.sh"]
}

provider "vsphere" {
  vsphere_server       = data.external.vcenter.result.host
  allow_unverified_ssl = var.allow_unverified_ssl
}

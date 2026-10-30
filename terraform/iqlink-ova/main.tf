locals {
  ova_file   = basename(split("?", var.ova_url)[0])
  ova_paths  = [for d in var.ova_cache_dirs : "${d}/${local.ova_file}"]
  ova_found  = [for p in local.ova_paths : p if fileexists(p)]
  local_path = length(local.ova_found) > 0 ? local.ova_found[0] : local.ova_paths[0]

  use_cluster = trimspace(var.cluster) != ""
  use_host    = trimspace(var.host) != ""
  folder      = trimspace(var.folder) == "" ? null : trimprefix(trimprefix(var.folder, "/${var.datacenter}/vm/"), "/")
}

data "vsphere_datacenter" "dc" {
  name = var.datacenter
}

data "vsphere_compute_cluster" "cluster" {
  count         = local.use_cluster ? 1 : 0
  name          = var.cluster
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_host" "host" {
  count         = local.use_host ? 1 : 0
  name          = var.host
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_datastore" "ds" {
  name          = var.datastore
  datacenter_id = data.vsphere_datacenter.dc.id
}

data "vsphere_network" "net" {
  name          = var.port_group
  datacenter_id = data.vsphere_datacenter.dc.id
}

locals {
  resource_pool_id = local.use_cluster ? data.vsphere_compute_cluster.cluster[0].resource_pool_id : data.vsphere_host.host[0].resource_pool_id
  host_system_id   = local.use_host ? data.vsphere_host.host[0].id : null
}

data "vsphere_ovf_vm_template" "ova" {
  name              = var.vm_name
  disk_provisioning = var.disk_provisioning
  resource_pool_id  = local.resource_pool_id
  datastore_id      = data.vsphere_datastore.ds.id
  host_system_id    = local.host_system_id
  local_ovf_path    = local.local_path
  ovf_network_map = {
    (var.ova_network_name) = data.vsphere_network.net.id
  }
}

resource "vsphere_virtual_machine" "iqlink" {
  name             = var.vm_name
  datacenter_id    = data.vsphere_datacenter.dc.id
  folder           = local.folder
  resource_pool_id = local.resource_pool_id
  datastore_id     = data.vsphere_datastore.ds.id
  host_system_id   = local.host_system_id

  num_cpus             = var.num_cpus > 0 ? var.num_cpus : data.vsphere_ovf_vm_template.ova.num_cpus
  num_cores_per_socket = data.vsphere_ovf_vm_template.ova.num_cores_per_socket
  memory               = var.memory_mb > 0 ? var.memory_mb : data.vsphere_ovf_vm_template.ova.memory
  memory_reservation   = var.reserve_all_memory ? (var.memory_mb > 0 ? var.memory_mb : data.vsphere_ovf_vm_template.ova.memory) : 0
  cpu_share_level      = var.cpu_share_level
  guest_id             = data.vsphere_ovf_vm_template.ova.guest_id
  firmware             = data.vsphere_ovf_vm_template.ova.firmware
  scsi_type            = data.vsphere_ovf_vm_template.ova.scsi_type

  dynamic "network_interface" {
    for_each = data.vsphere_ovf_vm_template.ova.ovf_network_map
    content {
      network_id = network_interface.value
    }
  }

  # The appliance blocks at the first-boot console wizard and has no IP until
  # the Day 0 grain runs, so never wait for guest networking here.
  wait_for_guest_net_timeout = 0
  wait_for_guest_ip_timeout  = 0

  ovf_deploy {
    allow_unverified_ssl_cert = var.allow_unverified_ssl
    local_ovf_path            = local.local_path
    disk_provisioning         = var.disk_provisioning
    ovf_network_map           = data.vsphere_ovf_vm_template.ova.ovf_network_map
  }

  lifecycle {
    ignore_changes = [ovf_deploy, disk, vapp, annotation, host_system_id]
  }
}

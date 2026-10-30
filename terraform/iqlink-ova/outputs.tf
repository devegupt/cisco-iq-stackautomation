output "vm_name" {
  value = vsphere_virtual_machine.iqlink.name
}

output "vm_uuid" {
  value = vsphere_virtual_machine.iqlink.uuid
}

output "vm_moid" {
  value = vsphere_virtual_machine.iqlink.moid
}

output "num_cpu" {
  value = vsphere_virtual_machine.iqlink.num_cpus
}

output "memory_mb" {
  value = vsphere_virtual_machine.iqlink.memory
}

output "power_state" {
  value = vsphere_virtual_machine.iqlink.power_state
}

output "datacenter" {
  value = var.datacenter
}

output "disk_provisioning" {
  value = var.disk_provisioning
}

output "ova_file" {
  value = local.ova_file
}

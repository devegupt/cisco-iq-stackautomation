variable "vm_name" {
  type        = string
  description = "Name of the Cisco IQ Link VM."
}

variable "ova_url" {
  type        = string
  description = "HTTP(S) URL of the Cisco IQ Link vSphere OVA. Downloaded to the runner by scripts/download-ova.sh before terraform init."
}

variable "ova_cache_dirs" {
  type        = list(string)
  description = "Directories searched (in order) for the OVA cached by download-ova.sh. Must match the script."
  default     = ["/storage/ova-cache", "/tmp/ova-cache"]
}

variable "datacenter" {
  type = string
}

variable "cluster" {
  type        = string
  default     = ""
  description = "Cluster name. Leave empty to place the VM on 'host' instead."
}

variable "host" {
  type        = string
  default     = ""
  description = "ESXi host. Required when cluster is empty; optional pin when a cluster is set (needed on clusters with HA/manual DRS)."
}

variable "datastore" {
  type = string
}

variable "folder" {
  type        = string
  default     = ""
  description = "VM folder path relative to the datacenter's vm folder (optional)."
}

variable "port_group" {
  type        = string
  description = "Port group mapped to the OVA's single network ('DHCP Network')."
}

variable "ova_network_name" {
  type        = string
  default     = "DHCP Network"
  description = "Source network name inside the OVA (verified in the 1.2.4017 and 1.3.0 OVF descriptors)."
}

variable "num_cpus" {
  type        = number
  default     = 0
  description = "vCPUs. 0 keeps the OVA default (16 in 1.2.4017)."
}

variable "memory_mb" {
  type        = number
  default     = 0
  description = "RAM in MB (use GB x 1024). 0 keeps the OVA default (32768 in 1.2.4017)."
}

variable "disk_provisioning" {
  type        = string
  default     = "thick"
  description = "thin, thick (lazy zeroed) or eagerZeroedThick. Cisco recommends thick."
  validation {
    condition     = contains(["thin", "thick", "eagerZeroedThick"], var.disk_provisioning)
    error_message = "disk_provisioning must be thin, thick or eagerZeroedThick."
  }
}

variable "reserve_all_memory" {
  type        = bool
  default     = true
  description = "Reserve all guest memory (Cisco IQ Link getting started guide, VMware step 13)."
}

variable "cpu_share_level" {
  type        = string
  default     = "low"
  description = "CPU shares (guide: Low)."
}

variable "allow_unverified_ssl" {
  type    = bool
  default = true
}

# Cisco IQ Link manual setup: screenshot walkthrough

These screenshots record one manual deployment of `cisco-iq-link-vsphere-1.3.0-v1.3.359.ova` (2026-10-28).
File names follow the order the screenshots were taken: `NN-step_YYYY-MM-DD_HH-MM-SS.png`, where the timestamp comes from the original capture. Sorting by name gives the capture order.
They are the reference for automating the same steps:
- **Part 1:** the OVA deploy, done by the blueprint's Terraform step.
- **Part 2:** the console Day 0 setup, done by govc keystrokes in `scripts/iqlink_day0_console.sh`.

The example values shown are lab values. In the blueprint, every one of them is an input.

## Part 1: Deploy the OVA in vCenter (`01-vcenter-ova-deploy/`)
| # | File | Step | What was entered or selected | Blueprint input |
|---|---|---|---|---|
| 1 | `01-select-ovf-template_2026-10-28_18-13-21.png` | Select an OVF template | Local file `cisco-iq-link-vsphere-1.3.0-v1.3.359.ova` | `ova_url` (remote URL) |
| 2 | `02-name-and-folder_2026-10-28_18-13-40.png` | Name and folder | VM name `devegupt-cisco-iq-link`, folder under datacenter `SVS` | `vm_name`, `datacenter`, `folder` |
| 3 | `03-compute-resource_2026-10-28_18-13-51.png` | Compute resource | Cluster `SVS General Purpose Cluster` | `cluster` |
| 4 | `04-review-details_2026-10-28_18-14-56.png` | Review details | 6.7 GB download; 9.6 GB thin or 487.3 GB thick; "No certificate present"; advanced-configuration warning | (none) |
| 5 | `05-storage-thin-provision_2026-10-28_18-15-19.png` | Select storage | Thin Provision, datastore `GeneralCluster2_N31` | `datastore`, `disk_provisioning` (default thin) |
| 6 | `06-networks-dhcp-network-mapping_2026-10-28_18-15-41.png` | Select networks | Source network **`DHCP Network`** → `vlan226`; IP allocation Static-Manual, IPv4 | `port_group` |
| 7 | `07-ready-to-complete_2026-10-28_18-15-53.png` | Ready to complete | Summary, then click Finish. Then power on the VM | (none) |
| 8 | `08-review-details-advanced-config_2026-10-28_18-27-32.png` | Review details, scrolled (captured later, at 18:27) | ExtraConfig: `disk.EnableUUID=TRUE`, `pciBridge4-7` PCIe root ports. **No vApp / "Customize template" step** | (none) |

## Part 2: First-boot console setup (`02-console-day0/`)
| # | File | Prompt on screen | Answer | Blueprint input |
|---|---|---|---|---|
| 1 | `01-login-banner_2026-10-28_19-13-00.png` | `cxue-infra login:` | (wait for this prompt; boot finished) | (none) |
| 2 | `02-login-admin_2026-10-28_19-13-24.png` | `cxue-infra login:` | `admin` | (none) |
| 3 | `03-password-prompt_2026-10-28_19-13-34.png` | `Password:` | `admin` (factory default) | `default_password` (hidden) |
| 4 | `04-main-menu_2026-10-28_19-13-43.png` | `Select a menu option:` (status "Not configured", hostname `CIQ-INFRA-HOST`) | `1` = Configure Network Settings | (none) |
| 5 | `05-network-settings-prompts_2026-10-28_19-18-52.png` | `Enter IP Address/Mask` | `10.122.226.150/24` | `mgmt_ip_cidr` |
| | | `Enter Gateway IP` | `10.122.226.1` | `gateway` |
| | | `Enter DNS IP List (comma-separated)` | `72.163.128.140,64.104.128.236,8.8.8.8,8.8.4.4` | `dns_list` |
| | | `Enter Search Domain` (default `local.domain`) | `cisco.com` | `search_domain` |
| | | `Enter NTP Server List` | `1.ntp.esl.cisco.com` | `ntp_servers` |
| | | `Configure NTP clock-comparison frequency? [y]/[N]` | `N` | (none) |
| | | `Configure NTP authentication? [y]/[N]` | `N` | (none) |
| | | `Enter New Password for Admin:` (rules shown on screen) | new password | `admin_password` (secret) |
| | | `Confirm Password:` | same password | (none) |
| 6 | `06-apply-configuration_2026-10-28_19-19-17.png` | Summary + `Apply this network configuration? [Y]/[n]` | `Y` (after checking the summary shows the IP) | (none) |

**Password rules shown on screen:**
- at least 15 characters
- at least 2 uppercase, 2 lowercase, 2 numbers, 2 special characters
- no repeating characters (e.g. `aa`, `11`)
- spaces and all printable characters are allowed

For keystroke automation, use only US-keyboard ASCII characters.

## Notes for automation
- **No vApp properties:** the OVA has no vApp properties, so there is no "Customize template" page in the wizard. Network setup is only possible at the console.
- **Keyboard:** the vSphere web console has an "Enforce US Keyboard Layout" option. govc keystrokes assume a US layout.
- **Lab OVA version:** the Stack Automation lab uses `1.2.4-v1.2.4017`. Re-check the prompts against these screenshots for that version.
- **After Apply:** the appliance should answer on the new IP (TCP 22/443). Pairing with Cisco IQ (Device ID + claim code, 5-minute expiry) stays manual.

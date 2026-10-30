# cisco-iq-stackautomation

A Stack Automation (Quali) blueprint that deploys the **Cisco IQ Link** OVA to vCenter and runs its first-boot (Day 0) setup without anyone working at the console.

The OVA is used exactly as the BU ships it. Day 0 is done externally, by govc console keystrokes.

## Layout
```
blueprints/cisco-iq-link.yaml   Stack Automation blueprint (spec_version 2)
terraform/iqlink-ova/      vSphere OVA deploy module (Terraform grain)
scripts/iqlink_precheck.sh  fail-fast checks before deploy (password policy, IP free, PTR, OVA reachable)
scripts/download-ova.sh    caches the OVA on the runner before terraform init (and destroy placeholder)
scripts/iqlink_day0_console.sh   Day 0 via govc keystrokes + OCR (shell grain)
instructions/              launch instructions shown in Stack Automation
screenshots/               manual walkthrough; see screenshots/README.md
  01-vcenter-ova-deploy/   vCenter "Deploy OVF Template" wizard, steps 1-7
  02-console-day0/         first-boot console prompts, in order
docs/                      design notes
```

## Flow
0. **Precheck** (shell): checks the password policy, that the gateway is in the subnet, that the IP is free, reverse DNS, and that the OVA is reachable. It runs in seconds, before anything is downloaded.
1. **Terraform grain:** deploy the OVA from `ova_url`, then power on the VM. Don't wait for an IP; none exists until Day 0 is done.
2. **Shell grain** (on the Management Server): run `scripts/iqlink_day0_console.sh`. It types the console answers with govc and checks that the new IP answers.
3. **Health check:** waits for `https://<mgmt_ip>` (installer UI).
4. **Output:** `https://<mgmt_ip>`. Pairing with Cisco IQ (Device ID + claim code) stays manual.

## Status (2026-10-31)
- [x] OVA reachable from Pablo's AWS link (1.2.4-v1.2.4017)
- [x] Screenshots organized by capture time, with an index
- [x] New Stack Automation account connected; space `Cisco-IQ` created
- [x] Blueprint, Terraform module and scripts written. Terraform validate OK, yamllint OK, OCR patterns tested on the screenshots
- [x] Stack Automation validator: only error is "no target in this space" (expected)
- [x] DMZ integration `bgl-dmz-vcenter` (Management Server 192.168.177.39) linked to space `Cisco-IQ` (API)
- [x] Blueprint revised from the catalog patterns (Cyber Vision, ISE, ThousandEyes, FMC, Veeam); validator reports only missing repo and target
- [ ] In the UI: create a **vCenter target** from `bgl-dmz-vcenter` (with vCenter credentials) available to space `Cisco-IQ`
- [ ] In the UI: connect this repo to space `Cisco-IQ` with repository name **`cisco-iq-stackautomation`** (blueprints/ is auto-discovered)
- [ ] First launch in the lab; on failure: Deployment → Orchestration → Logs
- [ ] Confirm the 1.2.4017 console prompts (expected: no NTP poll-frequency question)

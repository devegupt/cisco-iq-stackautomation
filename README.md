# cisco-iq-stackautomation

A Stack Automation (Quali) blueprint that deploys the **Cisco IQ Link** OVA to vCenter and runs its first-boot (Day 0) setup without anyone working at the console.

The OVA is used exactly as the BU ships it. Day 0 is done externally, by govc console keystrokes.

## Layout
```
blueprints/                Stack Automation blueprint YAML (spec_version 2)
terraform/iqlink-ova/      vSphere OVA deploy module (Terraform grain)
scripts/                   iqlink_day0_console.sh: Day 0 via govc keystrokes (shell grain)
screenshots/               manual walkthrough; see screenshots/README.md
  01-vcenter-ova-deploy/   vCenter "Deploy OVF Template" wizard, steps 1-7
  02-console-day0/         first-boot console prompts, in order
docs/                      design notes
```

## Flow
1. **Terraform grain:** deploy the OVA from `ova_url`, then power on the VM. Don't wait for an IP; none exists until Day 0 is done.
2. **Shell grain** (on the Management Server): run `scripts/iqlink_day0_console.sh`. It types the console answers with govc and checks that the new IP answers.
3. **Output:** `https://<mgmt_ip>`. Pairing with Cisco IQ (Device ID + claim code) stays manual.

## Status (2026-10-31)
- [x] OVA reachable from Pablo's AWS link (works with Stack Automation)
- [x] Console screenshots captured and organized (`screenshots/`)
- [x] Day 0 console script (fixed version)
- [ ] New Stack Automation account: API key, then MCP connection (old trial expired)
- [ ] Connect this repo to the new Stack Automation space
- [ ] Draft blueprint and Terraform module
- [ ] Lab test; check outputs. On failure: Deployment → Orchestration → Logs
- [ ] Optional: ask the in-product co-pilot to generate the govc step from `screenshots/`, and compare it with our script

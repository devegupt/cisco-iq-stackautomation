# Cisco IQ Link on vCenter

Deploys the Cisco IQ Link OVA and completes the first-boot network setup automatically.
Pairing with Cisco IQ stays a manual step.

## Before you launch
- **Static IPv4 address** for IQ Link. DHCP is not supported.
- **DNS records** for that address: a **forward (A)** record and a **reverse (PTR)** record. The hostname must be lowercase.
- **Outbound TCP 443** from the IQ Link network to `iq.cisco.com` and to your region's server:
  - AMER: `us-west-2.iq.cisco.com`
  - EMEA: `eu-central-1.iq.cisco.com`
  - APJC: `ap-southeast-2.iq.cisco.com`

  This can go through a proxy, as long as the proxy does no SSL inspection.
- **Network access to devices:** SSH (22), SNMP (161) and HTTPS (443) from IQ Link to the devices it will discover.
- **vCenter target account** with permission to deploy VMs and to use the console: VirtualMachine.Interact PowerOn, ConsoleInteract, PutUsbScanCodes and CreateScreenshot.
- **Management Server access:** it must reach the OVA URL, vCenter on 443, GitHub (to install govc if it's missing), and the new IQ Link IP on 443.
- **Cisco IQ admin user:** start "Add Cisco IQ Link" in Cisco IQ at **Home > System Settings > Data Connectors**.

## After the deployment is Active
1. Open **IQ Link Installer** from the outputs: `https://<management IP>`.
2. Select your **Region**, click **Start**, enter the proxy if you need one, then click **Test Connectivity** → **Next**.
3. The installer shows a **Device ID** and a **Claim code**. They are valid for **5 minutes**.
4. In Cisco IQ, on the **Add Cisco IQ Link** page:
   - tick **I am ready to pair with an installed Cisco IQ Link**;
   - give the instance a name;
   - enter the Device ID and Claim code;
   - click **Submit**.
5. Go back to the installer to configure the internal network. Then add SNMP and SSH credentials and your devices.

Reference: [Cisco IQ Link Getting Started Guide](https://iq.cisco.com/docs/link/getting-started/link-getting-started.html)

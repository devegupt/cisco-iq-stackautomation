#!/bin/sh
# Prints the vCenter hostname for the vSphere provider as JSON (Terraform "external" data source).
# Stack Automation passes the Provider's Server URL unchanged in VSPHERE_SERVER, e.g.
# "https://nac-vcenter-hx.ssedc.local". The vSphere provider adds "https://" and "/sdk" itself, so a
# full URL becomes "https://https//host/sdk". Strip the scheme and any path.
s="${VSPHERE_SERVER:-}"
s="${s#*://}"
s="${s%%/*}"
printf '{"host":"%s"}\n' "$s"

# Copyright (c) 2024, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
#

################################################################################
# Customer Provided Equipment (CPE) - Site-to-Site VPN
################################################################################
resource "oci_core_cpe" "cpe" {
  compartment_id      = var.compartment_ocid
  display_name        = "CPE (${random_string.deploy_id.result}) [${count.index}]"
  cpe_device_shape_id = data.oci_core_cpe_device_shapes.cpe.cpe_device_shapes.0.cpe_device_shape_id
  ip_address          = oci_core_instance.cpe_instance[count.index].public_ip
  # is_private          = (var.cpe_visibility == "Private") ? true : false
  freeform_tags = local.oci_tag_values.freeformTags
  defined_tags  = local.oci_tag_values.definedTags

  count = 1
}

################################################################################
# DRG OCI Resource <> CPE - Site-to-Site VPN
################################################################################
resource "oci_core_drg" "drg" {
  compartment_id = var.compartment_ocid
  display_name   = "DRG for Site-To-Site VPN (${random_string.deploy_id.result})"
  freeform_tags  = local.oci_tag_values.freeformTags
  defined_tags   = local.oci_tag_values.definedTags
}
resource "oci_core_drg_route_distribution" "drg" {
  distribution_type = "IMPORT"
  drg_id            = oci_core_drg.drg.id
  display_name      = "DRG Route Distribution (${random_string.deploy_id.result})"
  freeform_tags     = local.oci_tag_values.freeformTags
  defined_tags      = local.oci_tag_values.definedTags
}
resource "oci_core_drg_route_distribution_statement" "drg" {
  drg_route_distribution_id = oci_core_drg_route_distribution.drg.id
  action                    = "ACCEPT"
  match_criteria {}
  priority = 1
}
resource "oci_core_drg_route_table" "drg" {
  drg_id                           = oci_core_drg.drg.id
  display_name                     = "DRG Route Table (${random_string.deploy_id.result})"
  import_drg_route_distribution_id = oci_core_drg_route_distribution.drg.id
  # is_ecmp_enabled = true
  freeform_tags = local.oci_tag_values.freeformTags
  defined_tags  = local.oci_tag_values.definedTags
}
resource "oci_core_drg_attachment" "drg" {
  drg_id             = oci_core_drg.drg.id
  drg_route_table_id = oci_core_drg_route_table.drg.id
  display_name       = "DRG Attachment (${random_string.deploy_id.result})"
  freeform_tags      = local.oci_tag_values.freeformTags
  defined_tags       = local.oci_tag_values.definedTags
  network_details {
    id   = var.existent_oci_vcn_ocid
    type = "VCN"
  }
}
resource "oci_core_drg_attachment_management" "drg" {
  attachment_type    = "IPSEC_TUNNEL"
  compartment_id     = var.compartment_ocid
  network_id         = data.oci_core_ipsec_connection_tunnels.tunnels.ip_sec_connection_tunnels[count.index].id
  drg_id             = oci_core_drg.drg.id
  display_name       = "DRG IPSec Attachment (${random_string.deploy_id.result}) [${count.index}]"
  drg_route_table_id = oci_core_drg_route_table.drg.id
  freeform_tags      = local.oci_tag_values.freeformTags
  defined_tags       = local.oci_tag_values.definedTags

  count = 2
}

################################################################################
# CPE IPSec Tunnel
################################################################################
resource "oci_core_ipsec" "ipsec" {
  compartment_id            = var.compartment_ocid
  display_name              = "IPSec Connection (${random_string.deploy_id.result}) [${count.index}]"
  cpe_id                    = oci_core_cpe.cpe[count.index].id
  drg_id                    = oci_core_drg.drg.id
  static_routes             = [lookup(local.network_cidrs, "CPE-REGIONAL-SUBNET-CIDR")]
  cpe_local_identifier      = oci_core_instance.cpe_instance[count.index].public_ip
  cpe_local_identifier_type = "IP_ADDRESS"
  freeform_tags             = local.oci_tag_values.freeformTags
  defined_tags              = local.oci_tag_values.definedTags

  count = 1
}
resource "oci_core_ipsec_connection_tunnel_management" "tunnel" {
  ipsec_id     = oci_core_ipsec.ipsec.0.id
  tunnel_id    = data.oci_core_ipsec_connection_tunnels.tunnels.ip_sec_connection_tunnels[count.index].id
  display_name = "ipsec-tunnel-${count.index}"
  routing      = "BGP"
  bgp_session_info {
    customer_bgp_asn      = "42069"
    customer_interface_ip = "${cidrhost(local.network_cidrs["BGP-CIDR-${count.index}"], 1)}/${split("/", local.network_cidrs["BGP-CIDR-${count.index}"])[1]}"
    oracle_interface_ip   = "${cidrhost(local.network_cidrs["BGP-CIDR-${count.index}"], 2)}/${split("/", local.network_cidrs["BGP-CIDR-${count.index}"])[1]}"
  }

  shared_secret = local.shared_secret_psk
  ike_version   = "V2"

  count = 2

  timeouts {
    create = "6m"
  }
}
locals {
  shared_secret_psk = sensitive(sha256(uuid())) # using local and sha256 to hash the shared secret. The secret does not appear in the state file.
}

### Important Security Notice ###
# The private key generated by this resource will be stored unencrypted in your Terraform state file.
# Use of this resource for production deployments is not recommended.
# Instead, generate a private key file outside of Terraform and distribute it securely to the system where Terraform will be run.

# Generate ssh keys to access Compute Instances, if generate_public_ssh_key=true, applies to the Compute
resource "tls_private_key" "compute_ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 2048
}
locals {
  ssh_authorized_key   = var.generate_public_ssh_key ? tls_private_key.compute_ssh_key.public_key_openssh : var.public_ssh_key
  instance_private_key = var.generate_public_ssh_key ? tls_private_key.compute_ssh_key.private_key_pem : var.instance_private_key
}
# Copyright (c) 2024, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
#

# Dependencies:
#   - terraform-oci-networking module

################################################################################
# Deployment Defaults
################################################################################
locals {
  deploy_id   = random_string.deploy_id.result
  deploy_tags = { "DeploymentID" = local.deploy_id, "AppName" = local.app_name, "Quickstart" = "terraform-oci-cpe", "Deployment" = "${local.app_name} (${local.deploy_id})" }
  oci_tag_values = {
    "freeformTags" = merge(var.tag_values.freeformTags, local.deploy_tags),
    "definedTags"  = var.tag_values.definedTags
  }
  app_name            = var.app_name
  app_name_normalized = substr(replace(lower(local.app_name), " ", "-"), 0, 6)
  app_name_for_dns    = substr(lower(replace(local.app_name, "/\\W|_|\\s/", "")), 0, 6)
}

resource "random_string" "deploy_id" {
  length  = 4
  special = false
}

################################################################################
# Required locals for the oci-networking and modules
################################################################################
locals {
  create_new_vcn                = (var.create_new_vcn) ? true : false
  vcn_display_name              = "[${local.app_name}] VCN for CPE on OCI (${local.deploy_id})"
  create_subnets                = (var.create_subnets) ? true : false
  subnets                       = concat(local.subnets_for_cpe)
  route_tables                  = concat(local.route_tables_for_cpe_and_dc)
  security_lists                = concat(local.security_lists_for_cpe)
  resolved_vcn_compartment_ocid = (var.create_new_compartment_for_cpe ? local.cpe_compartment_ocid : var.compartment_ocid)
  pre_vcn_cidr_blocks           = split(",", var.vcn_cidr_blocks)
  vcn_cidr_blocks               = contains(module.vcn.cidr_blocks, local.pre_vcn_cidr_blocks[0]) ? distinct(concat([local.pre_vcn_cidr_blocks[0]], module.vcn.cidr_blocks)) : module.vcn.cidr_blocks
  network_cidrs = {
    VCN-MAIN-CIDR                = local.vcn_cidr_blocks[0]                     # e.g.: "10.220.0.0/16" = 65536 usable IPs
    CPE-REGIONAL-SUBNET-CIDR     = cidrsubnet(local.vcn_cidr_blocks[0], 12, 0)  # e.g.: "10.220.0.0/28" = 15 usable IPs
    BASTION-REGIONAL-SUBNET-CIDR = cidrsubnet(local.vcn_cidr_blocks[0], 12, 32) # e.g.: "10.220.2.0/28" = 15 usable IPs (10.220.2.0 - 10.220.2.15)
    PUBLIC-REGIONAL-SUBNET-CIDR  = cidrsubnet(local.vcn_cidr_blocks[0], 6, 3)   # e.g.: "10.220.12.0/22" = 1021 usable IPs (10.220.12.0 - 10.220.15.255)
    PRIVATE-REGIONAL-SUBNET-CIDR = cidrsubnet(local.vcn_cidr_blocks[0], 6, 4)   # e.g.: "10.220.16.0/22" = 1021 usable IPs (10.220.16.0 - 10.220.19.255)
    BGP-CUSTOMER-CIDR-0          = cidrsubnet(local.vcn_cidr_blocks[0], 10, 80) # e.g.: "10.220.20.0/26" = 62 usable IPs (10.220.20.0 - 10.220.20.63)
    BGP-CUSTOMER-CIDR-1          = cidrsubnet(local.vcn_cidr_blocks[0], 10, 81) # e.g.: "10.220.20.64/26" = 62 usable IPs (10.220.20.64 - 10.220.20.127)
    BGP-ORACLE-CIDR-0            = cidrsubnet(local.vcn_cidr_blocks[0], 10, 82) # e.g.: "10.220.20.128/26" = 62 usable IPs (10.220.20.128 - 10.220.20.191)
    BGP-ORACLE-CIDR-1            = cidrsubnet(local.vcn_cidr_blocks[0], 10, 83) # e.g.: "10.220.20.192/26" = 62 usable IPs (10.220.20.192 - 10.220.20.255)
    ALL-CIDR                     = "0.0.0.0/0"
  }
}
# Copyright (c) 2024, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
#

# Available OCI Services
data "oci_core_services" "all_services_network" {
  filter {
    name   = "name"
    values = ["All .* Services In Oracle Services Network"]
    regex  = true
  }
}

# Latest Image for CPE Compute Instance
data "oci_core_images" "cpe_compute_images" {
  compartment_id           = var.compartment_ocid
  operating_system         = var.cpe_image_operating_system
  operating_system_version = var.cpe_image_operating_system_version
  shape                    = var.cpe_instance_shape.instanceShape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# CPE Device Shapes per vendor
data "oci_core_cpe_device_shapes" "cpe" {
  filter {
    name   = "cpe_device_info.vendor"
    values = [var.cpe_vendor]
  }
}

# Latest Image for Example LDAP Compute Instance
data "oci_core_images" "ldap_compute_images" {
  compartment_id           = var.compartment_ocid
  operating_system         = var.ldap_image_operating_system
  operating_system_version = var.ldap_image_operating_system_version
  shape                    = var.ldap_instance_shape.instanceShape
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Get IPSec Tunnels
data "oci_core_ipsec_connection_tunnels" "tunnels" {
  ipsec_id = oci_core_ipsec.ipsec.0.id
}

# Gets a list of Availability Domains
data "oci_identity_availability_domains" "ADs" {
  compartment_id = var.tenancy_ocid
}

# Check for resource limits
## Check available compute shape
data "oci_limits_services" "compute_services" {
  compartment_id = var.tenancy_ocid

  filter {
    name   = "name"
    values = ["compute"]
  }
}
data "oci_limits_limit_definitions" "compute_limit_definitions" {
  compartment_id = var.tenancy_ocid
  service_name   = data.oci_limits_services.compute_services.services.0.name

  filter {
    name   = "description"
    values = [local.compute_shape_description]
  }
}
data "oci_limits_resource_availability" "compute_resource_availability" {
  compartment_id      = var.tenancy_ocid
  limit_name          = data.oci_limits_limit_definitions.compute_limit_definitions.limit_definitions[0].name
  service_name        = data.oci_limits_services.compute_services.services.0.name
  availability_domain = data.oci_identity_availability_domains.ADs.availability_domains[count.index].name

  count = length(data.oci_identity_availability_domains.ADs.availability_domains)
}
resource "random_shuffle" "compute_ad" {
  input        = local.compute_available_limit_ad_list
  result_count = length(local.compute_available_limit_ad_list)
}

locals {
  compute_multiplier_nodes_ocpus  = local.is_flexible_cpe_instance_shape ? (var.cpe_instance_shape.ocpus) : 1
  compute_available_limit_ad_list = [for limit in data.oci_limits_resource_availability.compute_resource_availability : limit.availability_domain if(limit.available - local.compute_multiplier_nodes_ocpus) >= 0]
  compute_available_limit_check = length(local.compute_available_limit_ad_list) == 0 ? (
  file("ERROR: No limits available for the chosen compute shape and number of nodes or OCPUs")) : 0
}

locals {
  compute_flexible_shapes = [
    "VM.Standard.E3.Flex",
    "VM.Standard.E4.Flex",
    "VM.Standard.E5.Flex",
    "VM.Standard.A1.Flex"
  ]
  compute_shape_flexible_descriptions = [
    "Cores for Standard.E3.Flex and BM.Standard.E3.128 Instances",
    "Cores for Standard.E4.Flex and BM.Standard.E4.128 Instances",
    "Cores for Standard.E5.Flex and BM.Standard.E5.128 Instances",
    "Cores for Standard.A1 based VM and BM Instances"
  ]
  compute_arm_shapes = [
    "VM.Standard.A1.Flex",
    "BM.Standard.A1.160"
  ]
  compute_shape_flexible_vs_descriptions = zipmap(local.compute_flexible_shapes, local.compute_shape_flexible_descriptions)
  compute_shape_description              = lookup(local.compute_shape_flexible_vs_descriptions, var.cpe_instance_shape.instanceShape, var.cpe_instance_shape.instanceShape)
}

# Cloud Init
## CPE
data "cloudinit_config" "cpe" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content      = local.cloud_init_cpe
  }
}
## Example LDAP Server
data "cloudinit_config" "ldap_server" {
  gzip          = true
  base64_encode = true

  part {
    filename     = "cloud-config.yaml"
    content_type = "text/cloud-config"
    content      = local.cloud_init_ldap_server
  }
}

## Files and Templatefiles
locals {
  setup_preflight = file("${path.module}/cloudinit/setup.preflight.sh")
  setup_cpe_template = templatefile("${path.module}/cloudinit/setup_cpe.template.sh",
    {
      oracle_client_version = "xx"
  })
  deploy_template = templatefile("${path.module}/cloudinit/deploy.template.sh",
    {
      oracle_client_version = "xx"
  })
  #   ,{
  #     oracle_client_version   = var.oracle_client_version
  # })
  cloud_init_cpe = templatefile("${path.module}/cloudinit/cloud_config_cpe.template.yaml",
    {
      shared_secret_psk = local.shared_secret_psk
  })
  cloud_init_ldap_server = templatefile("${path.module}/cloudinit/cloud_config_ldap.template.yaml",
    {
      setup_preflight_sh_content = base64gzip(local.setup_preflight)
      # setup_template_sh_content  = base64gzip(local.setup_template)
      deploy_template_content = base64gzip(local.deploy_template)
  })
}

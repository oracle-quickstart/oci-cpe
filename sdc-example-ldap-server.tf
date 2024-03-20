# Copyright (c) 2024, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
#

resource "oci_core_instance" "ldap_instance" {
  availability_domain = random_shuffle.compute_ad.result[count.index % length(random_shuffle.compute_ad.result)]
  compartment_id      = var.compartment_ocid
  display_name        = "Example LDAP Server (${random_string.deploy_id.result})"
  shape               = var.ldap_instance_shape.instanceShape
  # is_pv_encryption_in_transit_enabled = var.is_pv_encryption_in_transit_enabled
  freeform_tags = local.oci_tag_values.freeformTags
  defined_tags  = local.oci_tag_values.definedTags

  dynamic "shape_config" {
    for_each = local.is_flexible_cpe_instance_shape ? [1] : []
    content {
      ocpus         = var.ldap_instance_shape.ocpus
      memory_in_gbs = var.ldap_instance_shape.memory
    }
  }

  source_details {
    source_type = "image"
    source_id   = lookup(data.oci_core_images.ldap_compute_images.images[0], "id")
    # kms_key_id  = var.use_encryption_from_oci_vault ? (var.create_new_encryption_key ? oci_kms_key.cpe_key[0].id : var.encryption_key_id) : null
  }

  create_vnic_details {
    subnet_id        = (var.ldap_instance_visibility == "Private") ? module.subnets["private_subnet"].subnet_id : module.subnets["public_subnet"].subnet_id
    display_name     = "primaryvnic"
    assign_public_ip = (var.ldap_instance_visibility == "Private") ? false : true
    hostname_label   = "ldap-${random_string.deploy_id.result}-${count.index}"
  }

  metadata = {
    ssh_authorized_keys = local.ssh_authorized_key
    user_data           = data.cloudinit_config.ldap_server.rendered
  }

  count = 1
}

# Copyright (c) 2024, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
#

resource "oci_core_instance" "cpe_instance" {
  availability_domain = random_shuffle.compute_ad.result[count.index % length(random_shuffle.compute_ad.result)]
  compartment_id      = var.compartment_ocid
  display_name        = "CPE Instance - ${var.cpe_vendor} (${random_string.deploy_id.result}) [${count.index}]"
  shape               = var.cpe_instance_shape.instanceShape
  # is_pv_encryption_in_transit_enabled = var.is_pv_encryption_in_transit_enabled
  freeform_tags = local.oci_tag_values.freeformTags
  defined_tags  = local.oci_tag_values.definedTags

  dynamic "shape_config" {
    for_each = local.is_flexible_cpe_instance_shape ? [1] : []
    content {
      ocpus         = var.cpe_instance_shape.ocpus
      memory_in_gbs = var.cpe_instance_shape.memory
    }
  }

  source_details {
    source_type = "image"
    source_id   = lookup(data.oci_core_images.cpe_compute_images.images[0], "id")
    # kms_key_id  = var.use_encryption_from_oci_vault ? (var.create_new_encryption_key ? oci_kms_key.cpe_key[0].id : var.encryption_key_id) : null
  }

  create_vnic_details {
    subnet_id        = var.create_subnets ? module.subnets["cpe_subnet"].subnet_id : var.existent_cpe_subnet_ocid
    display_name     = "primaryvnic"
    assign_public_ip = (var.cpe_visibility == "Private") ? false : true
    hostname_label   = "cpe-${random_string.deploy_id.result}-${count.index}"
    skip_source_dest_check = true
  }

  metadata = {
    ssh_authorized_keys = local.ssh_authorized_key
    user_data           = data.cloudinit_config.cpe.rendered
  }

  count = 1
}

locals {
  # Checks if is using Flexible Compute Shapes
  is_flexible_cpe_instance_shape = contains(split(".", var.cpe_instance_shape.instanceShape), "Flex")
}

# Compartment for CPE
resource "oci_identity_compartment" "cpe_compartment" {
  compartment_id = var.compartment_ocid
  name           = "${local.app_name_normalized}-${local.deploy_id}"
  description    = "${local.app_name} ${var.cpe_compartment_description} (Deployment ${local.deploy_id})"
  enable_delete  = true

  count = var.create_new_compartment_for_cpe ? 1 : 0
}
locals {
  cpe_compartment_ocid = var.create_new_compartment_for_cpe ? oci_identity_compartment.cpe_compartment.0.id : var.compartment_ocid
}

# CPE Subnets definitions
locals {
  subnets_for_cpe = concat(local.cpe_subnet, local.subnet_bastion)
  cpe_subnet = [
    {
      subnet_name                  = "cpe_subnet"
      cidr_block                   = lookup(local.network_cidrs, "CPE-REGIONAL-SUBNET-CIDR")
      display_name                 = "CPE subnet (${local.deploy_id})"
      dns_label                    = "cpe${local.deploy_id}"
      prohibit_public_ip_on_vnic   = (var.cpe_visibility == "Private") ? true : false
      prohibit_internet_ingress    = (var.cpe_visibility == "Private") ? true : false
      # route_table_id               = (var.cpe_visibility == "Private") ? module.route_tables["private"].route_table_id : module.route_tables["public"].route_table_id
      alternative_route_table_name = null
      dhcp_options_id              = module.vcn.default_dhcp_options_id
      security_list_ids            = [module.security_lists["cpe_security_list"].security_list_id]
      extra_security_list_names    = [] #anytrue([(var.extra_security_list_name_for_cpe == ""), (var.extra_security_list_name_for_cpe == null)]) ? [] : [var.extra_security_list_name_for_cpe]
      ipv6cidr_block               = null
    },
    {
      subnet_name                  = "public_subnet"
      cidr_block                   = lookup(local.network_cidrs, "PUBLIC-REGIONAL-SUBNET-CIDR")
      display_name                 = "Simulated Data Center Public subnet (${local.deploy_id})"
      dns_label                    = "public${local.deploy_id}"
      prohibit_public_ip_on_vnic   = false
      prohibit_internet_ingress    = false
      route_table_id               = module.route_tables["public"].route_table_id
      alternative_route_table_name = null
      dhcp_options_id              = module.vcn.default_dhcp_options_id
      security_list_ids            = [module.security_lists["public_security_list"].security_list_id]
      extra_security_list_names    = []
      ipv6cidr_block               = null
    },
    {
      subnet_name                  = "private_subnet"
      cidr_block                   = lookup(local.network_cidrs, "PRIVATE-REGIONAL-SUBNET-CIDR")
      display_name                 = "Simulated Data Center Private subnet (${local.deploy_id})"
      dns_label                    = "private${local.deploy_id}"
      prohibit_public_ip_on_vnic   = true
      prohibit_internet_ingress    = true
      route_table_id               = module.route_tables["private"].route_table_id
      alternative_route_table_name = null
      dhcp_options_id              = module.vcn.default_dhcp_options_id
      security_list_ids            = [module.security_lists["private_security_list"].security_list_id]
      extra_security_list_names    = []
      ipv6cidr_block               = null
    }
  ]
  subnet_bastion = (var.create_bastion_subnet) ? [
    {
      subnet_name                  = "bastion_subnet"
      cidr_block                   = lookup(local.network_cidrs, "BASTION-REGIONAL-SUBNET-CIDR") # e.g.: 10.20.2.0/28 (12,32) = 15 usable IPs (10.20.2.0 - 10.20.2.15)
      display_name                 = "Bastion subnet (${local.deploy_id})"
      dns_label                    = "bastion${local.deploy_id}"
      prohibit_public_ip_on_vnic   = (var.bastion_visibility == "Private") ? true : false
      prohibit_internet_ingress    = (var.bastion_visibility == "Private") ? true : false
      route_table_id               = (var.bastion_visibility == "Private") ? module.route_tables["private"].route_table_id : module.route_tables["public"].route_table_id
      alternative_route_table_name = null
      dhcp_options_id              = module.vcn.default_dhcp_options_id
      security_list_ids            = [module.security_lists["bastion_security_list"].security_list_id]
      extra_security_list_names    = []
      ipv6cidr_block               = null
  }] : []
}

# Route Tables definitions
locals {
  route_tables_for_cpe_and_dc = [
    {
      route_table_name = "private"
      display_name     = "Private Route Table (${local.deploy_id})"
      route_rules = [
        {
          description       = "Traffic to the internet"
          destination       = lookup(local.network_cidrs, "ALL-CIDR")
          destination_type  = "CIDR_BLOCK"
          network_entity_id = module.gateways.nat_gateway_id
        },
        {
          description       = "Traffic to OCI services"
          destination       = lookup(data.oci_core_services.all_services_network.services[0], "cidr_block")
          destination_type  = "SERVICE_CIDR_BLOCK"
          network_entity_id = module.gateways.service_gateway_id
      }]

    },
    {
      route_table_name = "public"
      display_name     = "Public Route Table (${local.deploy_id})"
      route_rules = [
        {
          description       = "Traffic to/from internet"
          destination       = lookup(local.network_cidrs, "ALL-CIDR")
          destination_type  = "CIDR_BLOCK"
          network_entity_id = module.gateways.internet_gateway_id
      }]
  }]
}

# CPE Security Lists definitions
locals {
  security_lists_for_cpe = [
    {
      security_list_name = "cpe_security_list"
      display_name       = "CPE Security List (${local.deploy_id})"
      egress_security_rules = [
        {
          description      = "Allow CPE to communicate with internet"
          destination      = lookup(local.network_cidrs, "ALL-CIDR")
          destination_type = "CIDR_BLOCK"
          protocol         = local.security_list_ports.all_protocols
          stateless        = false
          tcp_options      = { max = -1, min = -1, source_port_range = null }
          udp_options      = { max = -1, min = -1, source_port_range = null }
          icmp_options     = null
          }, {
          description      = "Allow CPE to communicate with Simulated Data Center"
          destination      = lookup(local.network_cidrs, "PRIVATE-REGIONAL-SUBNET-CIDR")
          destination_type = "CIDR_BLOCK"
          protocol         = local.security_list_ports.all_protocols
          stateless        = false
          tcp_options      = { max = -1, min = -1, source_port_range = null }
          udp_options      = { max = -1, min = -1, source_port_range = null }
          icmp_options     = null
          }, {
          description      = "Path discovery"
          destination      = lookup(local.network_cidrs, "PRIVATE-REGIONAL-SUBNET-CIDR")
          destination_type = "CIDR_BLOCK"
          protocol         = local.security_list_ports.icmp_protocol_number
          stateless        = false
          tcp_options      = { max = -1, min = -1, source_port_range = null }
          udp_options      = { max = -1, min = -1, source_port_range = null }
          icmp_options     = { type = "3", code = "4" }
      }]
      ingress_security_rules = [
        {
          description  = "Allows inbound traffic from the internet"
          source       = lookup(local.network_cidrs, "ALL-CIDR")
          source_type  = "CIDR_BLOCK"
          protocol     = local.security_list_ports.all_protocols
          stateless    = false
          tcp_options  = { max = -1, min = -1, source_port_range = null }
          udp_options  = { max = -1, min = -1, source_port_range = null }
          icmp_options = null
          }, {
          description  = "Allow inbound SSH traffic to CPE"
          source       = lookup(local.network_cidrs, (var.cpe_visibility == "Private") ? "VCN-MAIN-CIDR" : "ALL-CIDR")
          source_type  = "CIDR_BLOCK"
          protocol     = local.security_list_ports.tcp_protocol_number
          stateless    = false
          tcp_options  = { max = local.security_list_ports.ssh_port_number, min = local.security_list_ports.ssh_port_number, source_port_range = null }
          udp_options  = { max = -1, min = -1, source_port_range = null }
          icmp_options = null
          }, {
          description  = "Allow Simulated Data Center to communicate with CPE"
          source       = lookup(local.network_cidrs, "PRIVATE-REGIONAL-SUBNET-CIDR")
          source_type  = "CIDR_BLOCK"
          protocol     = local.security_list_ports.all_protocols
          stateless    = false
          tcp_options  = { max = -1, min = -1, source_port_range = null }
          udp_options  = { max = -1, min = -1, source_port_range = null }
          icmp_options = null
          }, {
          description  = "Path discovery"
          source       = lookup(local.network_cidrs, "ALL-CIDR")
          source_type  = "CIDR_BLOCK"
          protocol     = local.security_list_ports.icmp_protocol_number
          stateless    = false
          tcp_options  = { max = -1, min = -1, source_port_range = null }
          udp_options  = { max = -1, min = -1, source_port_range = null }
          icmp_options = { type = "3", code = "4" }
      }]
      }, {
      security_list_name = "private_security_list"
      display_name       = "SDC Private Security List (${local.deploy_id})"
      egress_security_rules = [
        {
          description      = "Allow SDC to communicate with internet"
          destination      = lookup(local.network_cidrs, "ALL-CIDR")
          destination_type = "CIDR_BLOCK"
          protocol         = local.security_list_ports.all_protocols
          stateless        = false
          tcp_options      = { max = -1, min = -1, source_port_range = null }
          udp_options      = { max = -1, min = -1, source_port_range = null }
          icmp_options     = null
          }, {
          description      = "Allow SDC to communicate with CPE"
          destination      = lookup(local.network_cidrs, "CPE-REGIONAL-SUBNET-CIDR")
          destination_type = "CIDR_BLOCK"
          protocol         = local.security_list_ports.all_protocols
          stateless        = false
          tcp_options      = { max = -1, min = -1, source_port_range = null }
          udp_options      = { max = -1, min = -1, source_port_range = null }
          icmp_options     = null
          }, {
          description      = "CPE Path discovery"
          destination      = lookup(local.network_cidrs, "CPE-REGIONAL-SUBNET-CIDR")
          destination_type = "CIDR_BLOCK"
          protocol         = local.security_list_ports.icmp_protocol_number
          stateless        = false
          tcp_options      = { max = -1, min = -1, source_port_range = null }
          udp_options      = { max = -1, min = -1, source_port_range = null }
          icmp_options     = { type = "3", code = "4" }
      }]
      ingress_security_rules = [
        {
          description  = "Allows inbound traffic from CPE"
          source       = lookup(local.network_cidrs, "CPE-REGIONAL-SUBNET-CIDR")
          source_type  = "CIDR_BLOCK"
          protocol     = local.security_list_ports.all_protocols
          stateless    = false
          tcp_options  = { max = -1, min = -1, source_port_range = null }
          udp_options  = { max = -1, min = -1, source_port_range = null }
          icmp_options = null
          }, {
          description  = "Allows inbound traffic from VCN"
          source       = lookup(local.network_cidrs, "VCN-MAIN-CIDR")
          source_type  = "CIDR_BLOCK"
          protocol     = local.security_list_ports.all_protocols
          stateless    = false
          tcp_options  = { max = -1, min = -1, source_port_range = null }
          udp_options  = { max = -1, min = -1, source_port_range = null }
          icmp_options = null
          }, {
          description  = "Path discovery"
          source       = lookup(local.network_cidrs, "VCN-MAIN-CIDR")
          source_type  = "CIDR_BLOCK"
          protocol     = local.security_list_ports.icmp_protocol_number
          stateless    = false
          tcp_options  = { max = -1, min = -1, source_port_range = null }
          udp_options  = { max = -1, min = -1, source_port_range = null }
          icmp_options = { type = "3", code = "4" }
      }]
      }, {
      security_list_name = "public_security_list"
      display_name       = "SDC Public Security List (${local.deploy_id})"
      egress_security_rules = [
        {
          description      = "Allow SDC to communicate with internet"
          destination      = lookup(local.network_cidrs, "ALL-CIDR")
          destination_type = "CIDR_BLOCK"
          protocol         = local.security_list_ports.all_protocols
          stateless        = false
          tcp_options      = { max = -1, min = -1, source_port_range = null }
          udp_options      = { max = -1, min = -1, source_port_range = null }
          icmp_options     = null
      }]
      ingress_security_rules = [
        {
          description  = "Allows inbound traffic from the internet"
          source       = lookup(local.network_cidrs, "ALL-CIDR")
          source_type  = "CIDR_BLOCK"
          protocol     = local.security_list_ports.all_protocols
          stateless    = false
          tcp_options  = { max = -1, min = -1, source_port_range = null }
          udp_options  = { max = -1, min = -1, source_port_range = null }
          icmp_options = null
          }, {
          description  = "Allow inbound SSH traffic to SDC"
          source       = lookup(local.network_cidrs, "ALL-CIDR")
          source_type  = "CIDR_BLOCK"
          protocol     = local.security_list_ports.tcp_protocol_number
          stateless    = false
          tcp_options  = { max = local.security_list_ports.ssh_port_number, min = local.security_list_ports.ssh_port_number, source_port_range = null }
          udp_options  = { max = -1, min = -1, source_port_range = null }
          icmp_options = null
      }]
      }, {
      security_list_name = "bastion_security_list"
      display_name       = "Bastion Security List (${local.deploy_id})"
      egress_security_rules = [
        {
          description      = "Allow Bastion to communicate with internet"
          destination      = lookup(local.network_cidrs, "ALL-CIDR")
          destination_type = "CIDR_BLOCK"
          protocol         = local.security_list_ports.all_protocols
          stateless        = false
          tcp_options      = { max = -1, min = -1, source_port_range = null }
          udp_options      = { max = -1, min = -1, source_port_range = null }
          icmp_options     = null
      }]
      ingress_security_rules = [
        {
          description  = "Allows inbound traffic from the internet"
          source       = lookup(local.network_cidrs, "ALL-CIDR")
          source_type  = "CIDR_BLOCK"
          protocol     = local.security_list_ports.all_protocols
          stateless    = false
          tcp_options  = { max = -1, min = -1, source_port_range = null }
          udp_options  = { max = -1, min = -1, source_port_range = null }
          icmp_options = null
          }, {
          description  = "Allow inbound SSH traffic to CPE"
          source       = lookup(local.network_cidrs, (var.cpe_visibility == "Private") ? "VCN-MAIN-CIDR" : "ALL-CIDR")
          source_type  = "CIDR_BLOCK"
          protocol     = local.security_list_ports.tcp_protocol_number
          stateless    = false
          tcp_options  = { max = local.security_list_ports.ssh_port_number, min = local.security_list_ports.ssh_port_number, source_port_range = null }
          udp_options  = { max = -1, min = -1, source_port_range = null }
          icmp_options = null
      }]
    }
  ]
  security_list_ports = {
    http_port_number     = 80
    https_port_number    = 443
    ssh_port_number      = 22
    tcp_protocol_number  = "6"
    icmp_protocol_number = "1"
    all_protocols        = "all"
  }
}

# Post-Provisioning Configuration
resource "null_resource" "cpe_oci_ipsec_conf" {
  triggers = {
    cpe_instance_ids = join(",", oci_core_instance.cpe_instance[*].id)
  }
  connection {
    type        = "ssh"
    user        = "opc"
    private_key = local.instance_private_key
    host        = element(oci_core_instance.cpe_instance[*].public_ip, 0)
  }
  provisioner "remote-exec" {
    inline = [
      "sudo sed -i -e 's|$cpe_local_ip|${element(oci_core_instance.cpe_instance[*].private_ip, 0)}|g' '/etc/ipsec.d/oci-ipsec.conf' || (echo ' *** Failed to update /etc/ipsec.d/oci-ipsec.conf. Exiting...' && exit 0)",
      "sudo sed -i -e 's|$cpe_public_ip|${element(oci_core_instance.cpe_instance[*].public_ip, 0)}|g' '/etc/ipsec.d/oci-ipsec.conf' || (echo ' *** Failed to update /etc/ipsec.d/oci-ipsec.conf. Exiting...' && exit 0)",
      "sudo sed -i -e 's|$oci_headend1|${data.oci_core_ipsec_connection_tunnels.tunnels.ip_sec_connection_tunnels[0].vpn_ip}|g' '/etc/ipsec.d/oci-ipsec.conf' || (echo ' *** Failed to update /etc/ipsec.d/oci-ipsec.conf. Exiting...' && exit 0)",
      "sudo sed -i -e 's|$oci_headend2|${data.oci_core_ipsec_connection_tunnels.tunnels.ip_sec_connection_tunnels[1].vpn_ip}|g' '/etc/ipsec.d/oci-ipsec.conf' || (echo ' *** Failed to update /etc/ipsec.d/oci-ipsec.conf. Exiting...' && exit 0)",
      "sudo sed -i -e 's|$cpe_public_ip|${element(oci_core_instance.cpe_instance[*].public_ip, 0)}|g' '/etc/ipsec.d/oci-ipsec.secrets' || (echo ' *** Failed to update /etc/ipsec.d/oci-ipsec.secrets. Exiting...' && exit 0)",
      "sudo sed -i -e 's|$oci_headend1|${data.oci_core_ipsec_connection_tunnels.tunnels.ip_sec_connection_tunnels[0].vpn_ip}|g' '/etc/ipsec.d/oci-ipsec.secrets' || (echo ' *** Failed to update /etc/ipsec.d/oci-ipsec.secrets. Exiting...' && exit 0)",
      "sudo sed -i -e 's|$oci_headend2|${data.oci_core_ipsec_connection_tunnels.tunnels.ip_sec_connection_tunnels[1].vpn_ip}|g' '/etc/ipsec.d/oci-ipsec.secrets' || (echo ' *** Failed to update /etc/ipsec.d/oci-ipsec.secrets. Exiting...' && exit 0)",
    ]
  }

  depends_on = [oci_core_ipsec_connection_tunnel_management.tunnel]
}

resource "null_resource" "cpe_oci_ipsec_service" {
  triggers = {
    cpe_instance_ids = join(",", oci_core_instance.cpe_instance[*].id)
  }
  connection {
    type        = "ssh"
    user        = "opc"
    private_key = local.instance_private_key
    host        = element(oci_core_instance.cpe_instance[*].public_ip, 0)
  }
  provisioner "remote-exec" {
    inline = [
      "sudo service ipsec restart",
      "sudo systemctl enable ipsec",
    ]
  }

  depends_on = [
    oci_core_ipsec_connection_tunnel_management.tunnel,
    null_resource.cpe_oci_ipsec_conf]
}

# Post Provisioning Route Tables
## CPE Route Table
resource "oci_core_default_route_table" "post_cpe_provisioning" {
    compartment_id = var.compartment_ocid
    manage_default_resource_id = module.vcn.default_route_table_id
    display_name = "CPE Post-Provisioning Default Route Table (${local.deploy_id})"
    freeform_tags = local.oci_tag_values.freeformTags
    defined_tags  = local.oci_tag_values.definedTags
    route_rules {
        network_entity_id = module.gateways.internet_gateway_id
        description = "Traffic to/from internet 2"
        destination = lookup(local.network_cidrs, "ALL-CIDR")
        destination_type = "CIDR_BLOCK"
    }
    route_rules {
        network_entity_id = data.oci_core_private_ips.cpe.private_ips.0.id
        description = "Traffic from OCI services to CPE"
        destination = data.oci_core_vcn.existent_oci_vcn.cidr_blocks.0
        destination_type = "CIDR_BLOCK"
    }

    depends_on = [ null_resource.cpe_oci_ipsec_service ]
}

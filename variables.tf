# Copyright (c) 2024, Oracle and/or its affiliates. All rights reserved.
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
#

################################################################################
# OCI Provider Variables
################################################################################
variable "tenancy_ocid" {}
variable "compartment_ocid" {}
variable "region" {}
variable "user_ocid" {
  default = ""
}
variable "fingerprint" {
  default = ""
}
variable "private_key_path" {
  default = ""
}


################################################################################
# App Name to identify deployment. Used for naming resources.
################################################################################
variable "app_name" {
  default     = "CPE Test"
  description = "Application name. Will be used as prefix to identify resources."
}
variable "tag_values" {
  type = map(any)
  default = { "freeformTags" = {
    "Environment" = "Test",         # e.g.: Demo, Sandbox, Development, QA, Stage, ...
    "DeploymentType" = "generic" }, # e.g.: App Type 1, App Type 2, Red, Purple, ...
  "definedTags" = {} }
  description = "Use Tagging to add metadata to resources. All resources created by this stack will be tagged with the selected tag values."
}

################################################################################
# Variables: Compute Instance - Generic
################################################################################
variable "generate_public_ssh_key" {
  default = true
}
variable "public_ssh_key" {
  default     = ""
  description = "In order to access your private nodes with a public SSH key you will need to set up a bastion host (a.k.a. jump box). If using public nodes, bastion is not needed. Left blank to not import keys."
}

################################################################################
# Variables: Compute Instance - CPE
################################################################################
variable "cpe_instance_shape" {
  type = map(any)
  default = {
    "instanceShape" = "VM.Standard.E4.Flex"
    "ocpus"         = 2
    "memory"        = 16
  }
  description = "A shape is a template that determines the number of OCPUs, amount of memory, and other resources allocated to a newly created instance."
}
variable "cpe_instance_boot_volume_size_in_gbs" {
  default     = "50"
  description = "Specify a custom boot volume size (in GB)"
}
variable "cpe_image_operating_system" {
  default     = "Oracle Linux"
  description = "The OS/image installed on all nodes in the node pool."
}
variable "cpe_image_operating_system_version" {
  default     = "9"
  description = "The OS/image version installed on all nodes in the node pool."
}
variable "create_new_compartment_for_cpe" {
  default     = false
  description = "Creates new compartment for CPE.  NOTE: The creation of the compartment increases the deployment time by at least 3 minutes, and can increase by 15 minutes when destroying"
}
variable "cpe_compartment_description" {
  default = "Compartment for CPE"
}

################################################################################
# Variables: CPE
################################################################################
variable "cpe_visibility" {
  default     = "Public"
  description = "CPE will be hosted in public or private subnet(s)"

  validation {
    condition     = var.cpe_visibility == "Private" || var.cpe_visibility == "Public"
    error_message = "Sorry, but CPE visibility can only be Private or Public."
  }
}
variable "extra_security_list_name_for_cpe" {
  default     = []
  description = "Extra security lists to be created."
}

################################################################################
# Variables: Bastion
################################################################################
variable "create_bastion_subnet" {
  default     = false
  description = "Creates a new Bastion Subnet."
}
variable "bastion_visibility" {
  default     = "Public"
  description = "Bastion will be hosted in public or private subnet(s)"

  validation {
    condition     = var.bastion_visibility == "Private" || var.bastion_visibility == "Public"
    error_message = "Sorry, but Bastion visibility can only be Private or Public."
  }
}

################################################################################
# Variables: OCI Networking
################################################################################
## VCN
variable "create_new_vcn" {
  default     = true
  description = "Creates a new Virtual Cloud Network (VCN). If false, the VCN must be provided in the variable 'existent_vcn_ocid'."
}
variable "existent_vcn_ocid" {
  default     = ""
  description = "Using existent Virtual Cloud Network (VCN) OCID."
}
variable "existent_vcn_compartment_ocid" {
  default     = ""
  description = "Compartment OCID for existent Virtual Cloud Network (VCN)."
}
variable "vcn_cidr_blocks" {
  default     = "10.100.0.0/16"
  description = "IPv4 CIDR Blocks for the Virtual Cloud Network (VCN). If use more than one block, separate them with comma. e.g.: 10.100.0.0/16,10.200.0.0/16. If you plan to peer this VCN with another VCN, the VCNs must not have overlapping CIDRs."
}
variable "is_ipv6enabled" {
  default     = false
  description = "Whether IPv6 is enabled for the Virtual Cloud Network (VCN)."
}
variable "ipv6private_cidr_blocks" {
  default     = []
  description = "The list of one or more ULA or Private IPv6 CIDR blocks for the Virtual Cloud Network (VCN)."
}
## Subnets
variable "create_subnets" {
  default     = true
  description = "Create subnets for CPE"
}

variable "existent_cpe_subnet_ocid" {
  default     = ""
  description = "Using existent CPE Subnet OCID."
}
variable "existent_private_subnet_ocid" {
  default     = ""
  description = "Using existent Private Subnet OCID."
}
variable "existent_public_subnet_ocid" {
  default     = ""
  description = "Using existent Public Subnet OCID."
}
# Terraform Customer-Premises Equipment (CPE) Quick Start

Welcome to the Terraform Customer-Premises Equipment (CPE) Quick Start repository! This repository provides a streamlined and efficient approach to provisioning Customer-Premises Equipment (CPE) on OCI using Terraform. This scripts simulate the deployment of a CPE device in a customer's on-premises environment, using [Libreswan](https://libreswan.org/), connecting to an Oracle Cloud Infrastructure (OCI) Virtual Cloud Network (VCN) using a Site-to-Site VPN with IPSec tunnels.

## Why use Terraform for CPE Deployment?

Terraform simplifies the process of deploying and managing infrastructure by enabling infrastructure as code (IaC) practices. With Terraform, you can define your CPE infrastructure requirements in configuration files, allowing for consistent, repeatable, and scalable deployments across different environments.

## Architecture

![OCI CPE Architecture](./images/oci_cpe_generic_architecture.png#gh-light-mode-only)![OCI CPE Architecture - Dark Mode](./images/oci_cpe_generic_architecture_dark.png#gh-dark-mode-only)

## Example usage Architecture (WebLogic example)

![OCI CPE Tutorial Architecture](./images/oci_cpe_wls_tutorial_architecture.png#gh-light-mode-only)![OCI CPE Architecture - Dark Mode](./images/oci_cpe_wls_tutorial_architecture_dark.png#gh-dark-mode-only)

## Getting Started

To get started with Terraform CPE Quick Start, you can deploy using the "Magic Button" to deploy using the OCI Resource Manager, which is a Terraform Worker on the Cloud, or simply clone this repository and follow the instructions provided in the [documentation](./DEPLOY.md). You'll be able to deploy CPE in no time, leveraging Terraform's simplicity and power.

### Deploying Using Oracle Resource Manager

> ___NOTE:___ If you aren't already signed in, when prompted, enter the tenancy and user credentials. Review and accept the terms and conditions.

1. Click to deploy the stack

    [![Deploy to Oracle Cloud][magic_button]][magic_cpe_stack]

1. Select the region and compartment where you want to deploy the stack.

1. Follow the on-screen prompts and instructions to create the stack.

1. After creating the stack, click Terraform Actions, and select Plan.

1. Wait for the job to be completed, and review the plan.

1. To make any changes, return to the Stack Details page, click Edit Stack, and make the required changes. Then, run the Plan action again.

1. If no further changes are necessary, return to the Stack Details page, click Terraform Actions, and select Apply.

### Other Deployment Options

For other deployment options, see [DEPLOY](./DEPLOY.md) for more details.

## License

Copyright (c) 2024 Oracle and/or its affiliates.
Released under the Universal Permissive License (UPL), Version 1.0.
See [LICENSE](./LICENSE) for more details.

[magic_button]: https://oci-resourcemanager-plugin.plugins.oci.oraclecloud.com/latest/deploy-to-oracle-cloud.svg
[magic_cpe_stack]: https://cloud.oracle.com/resourcemanager/stacks/create?zipUrl=https://github.com/oracle-quickstart/oci-cpe/releases/latest/download/oci-cpe-stack.zip

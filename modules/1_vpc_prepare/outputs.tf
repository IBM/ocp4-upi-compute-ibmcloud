################################################################
# Copyright 2023 - IBM Corporation. All rights reserved
# SPDX-License-Identifier: Apache-2.0
################################################################

output "vpc_check_key" {
  value = local.check_key
}

output "vpc_bootstrap_private_ip" {
  value = local.vsis == [] ? ibm_is_instance.supp_vm_vsi[0].primary_network_interface[0].primary_ip.0.address : local.vsis[0].primary_network_interface[0].primary_ip.0.address
}

output "vpc_crn" {
  value = data.ibm_is_vpc.vpc.crn
}

output "transit_gateway_id" {
  value = local.tg == [] ? ibm_tg_gateway.mac_tg_gw[0] : local.tg[0]
}

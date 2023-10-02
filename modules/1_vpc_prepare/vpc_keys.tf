################################################################
# Copyright 2023 - IBM Corporation. All rights reserved
# SPDX-License-Identifier: Apache-2.0
################################################################

# Manages the ssh keys

data "ibm_is_ssh_keys" "keys" {
  # Region is implicit
}

locals {
  # Avoid duplication, irrespective of the public key's name
  current_key = trimspace(file(local.public_key_file))
  key_comps   = split(" ", local.current_key)
  check_key   = "${local.key_comps[0]} ${local.key_comps[1]}"
  keys        = [for x in data.ibm_is_ssh_keys.keys.keys : x if x.public_key == local.check_key]
}

resource "ibm_is_ssh_key" "vpc_support_ssh_key_cond_create" {
  count          = local.keys == [] ? 1 : 0
  name           = "${var.vpc_name}-keypair"
  public_key     = local.public_key
  resource_group = data.ibm_is_vpc.vpc.resource_group
}

locals {
  key_id = local.keys == [] ? ibm_is_ssh_key.vpc_support_ssh_key_cond_create[0].id : local.keys[0].id
}

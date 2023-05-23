################################################################
# Copyright 2023 - IBM Corporation. All rights reserved
# SPDX-License-Identifier: Apache2.0
################################################################

locals {
  wildcard_dns   = ["nip.io", "xip.io", "sslip.io"]
  cluster_domain = contains(local.wildcard_dns, var.cluster_domain) ? "${var.bastion_external_vip != "" ? var.bastion_external_vip : var.bastion_public_ip[0]}.${var.cluster_domain}" : var.cluster_domain

  public_vrrp = {
    virtual_router_id = var.bastion_internal_vip == "" ? "" : split(".", var.bastion_internal_vip)[3]
    virtual_ipaddress = var.bastion_internal_vip
    password          = uuid()
  }

  node_labels = {
    "topology.kubernetes.io/region"    = var.region
    "topology.kubernetes.io/zone"      = var.zone
    "node.kubernetes.io/instance-type" = var.system_type
  }

  local_registry = {
    enable_local_registry = var.enable_local_registry
    registry_image        = var.local_registry_image
    ocp_release_repo      = "ocp4/openshift4"
    ocp_release_tag       = var.ocp_release_tag
    ocp_release_name      = var.ocp_release_name
  }

  helpernode_vars = {
    cluster_domain        = var.cluster_domain
    name_prefix           = var.name_prefix
    cluster_id            = var.cluster_id
    name_prefix           = var.name_prefix
    bastion_ip            = var.bastion_vip != "" ? var.bastion_vip : var.bastion_ip[0]
    bastion_name          = var.bastion_vip != "" ? "${var.name_prefix}bastion" : "${var.name_prefix}bastion-0"
    isHA                  = var.bastion_vip != ""
    bastion_master_ip     = var.bastion_ip[0]
    bastion_backup_ip     = length(var.bastion_ip) > 1 ? slice(var.bastion_ip, 1, length(var.bastion_ip)) : []
    forwarders            = var.dns_forwarders
    gateway_ip            = var.setup_snat ? (var.bastion_vip != "" ? var.bastion_vip : var.bastion_ip[0]) : var.gateway_ip
    netmask               = cidrnetmask(var.cidr)
    broadcast             = cidrhost(var.cidr, -1)
    ipid                  = cidrhost(var.cidr, 0)
    pool                  = { "start" : cidrhost(var.cidr, 2), "end" : cidrhost(var.cidr, -2) }
    chrony_config         = var.chrony_config
    chrony_config_servers = var.chrony_config_servers

    bootstrap_info = {
      ip   = var.bootstrap_ip
      mac  = var.bootstrap_mac
      name = "${var.node_prefix}bootstrap"
    }
    master_info = [for ix in range(length(var.master_ips)) :
      {
        ip   = var.master_ips[ix],
        mac  = var.master_macs[ix],
        name = "${var.node_prefix}master-${ix}"
      }
    ]
    worker_info = [for ix in range(length(var.worker_ips)) :
      {
        ip   = var.worker_ips[ix],
        mac  = var.worker_macs[ix],
        name = "${var.node_prefix}worker-${ix}"
      }
    ]

    local_registry  = local.local_registry
    client_tarball  = var.openshift_client_tarball
    install_tarball = var.openshift_install_tarball
  }

  helpernode_inventory = {
    rhel_username = var.rhel_username
    bastion_ip    = var.bastion_ip
  }

  install_inventory = {
    rhel_username  = var.rhel_username
    bastion_hosts  = [for ix in range(length(var.bastion_ip)) : "${var.name_prefix}bastion-${ix}"]
    bootstrap_host = var.bootstrap_ip == "" ? "" : "${var.node_prefix}bootstrap"
    master_hosts   = [for ix in range(length(var.master_ips)) : "${var.node_prefix}master-${ix}"]
    worker_hosts   = [for ix in range(length(var.worker_ips)) : "${var.node_prefix}worker-${ix}"]
  }

  proxy = {
    server    = lookup(var.proxy, "server", ""),
    port      = lookup(var.proxy, "port", "3128"),
    user_pass = lookup(var.proxy, "user", "") == "" ? "" : "${lookup(var.proxy, "user", "")}:${lookup(var.proxy, "password", "")}@"
  }

  local_registry_ocp_image = "registry.${var.cluster_id}.${var.cluster_domain}:5000/${local.local_registry.ocp_release_repo}:${var.ocp_release_tag}"

  install_vars = {
    bastion_vip              = var.bastion_vip
    cluster_id               = var.cluster_id
    cluster_domain           = var.cluster_domain
    pull_secret              = var.pull_secret
    public_ssh_key           = var.public_key
    storage_type             = var.storage_type
    log_level                = var.log_level
    release_image_override   = var.enable_local_registry ? local.local_registry_ocp_image : var.release_image_override
    enable_local_registry    = var.enable_local_registry
    fips_compliant           = var.fips_compliant
    rhcos_pre_kernel_options = var.rhcos_pre_kernel_options
    rhcos_kernel_options     = var.rhcos_kernel_options
    node_labels              = merge(local.node_labels, var.node_labels)
    chrony_config            = var.chrony_config
    chrony_config_servers    = var.chrony_config_servers
    chrony_allow_range       = var.cidr
    setup_squid_proxy        = var.setup_squid_proxy
    squid_source_range       = var.cidr
    proxy_url                = local.proxy.server == "" ? "" : "http://${local.proxy.user_pass}${local.proxy.server}:${local.proxy.port}"
    no_proxy                 = var.cidr
    cni_network_provider     = var.cni_network_provider
    # Set CNI network MTU to MTU - 100 for OVNKubernetes and MTU - 50 for OpenShiftSDN(default).
    # Add new conditions here when we have more network providers
    cni_network_mtu        = var.cni_network_provider == "OVNKubernetes" ? var.private_network_mtu - 100 : var.private_network_mtu - 50
    luks_compliant         = var.luks_compliant
    luks_config            = var.luks_config
    luks_filesystem_device = var.luks_filesystem_device
    luks_format            = var.luks_format
    luks_wipe_filesystem   = var.luks_wipe_filesystem
    luks_device            = var.luks_device
    luks_label             = var.luks_label
    luks_options           = var.luks_options
    luks_wipe_volume       = var.luks_wipe_volume
    luks_name              = var.luks_name
  }

  powervs_config_vars = {
    ibm_cloud_dl_endpoint_net_cidr = var.ibm_cloud_dl_endpoint_net_cidr
    ibm_cloud_http_proxy           = var.ibm_cloud_http_proxy
    ocp_node_net_gw                = var.gateway_ip
  }

  csi_driver_install_vars = {
    service_instance_id = var.service_instance_id
    region              = var.region
    zone                = var.zone
    csi_driver_type     = var.csi_driver_type
    csi_driver_version  = var.csi_driver_version
    master_info = [for ix in range(length(var.master_ids)) :
      {
        id   = var.master_ids[ix],
        name = "${var.node_prefix}master-${ix}.${var.cluster_id}.${local.cluster_domain}"
      }
    ]
    worker_info = [for ix in range(length(var.worker_ids)) :
      {
        id   = var.worker_ids[ix],
        name = "${var.node_prefix}worker-${ix}.${var.cluster_id}.${local.cluster_domain}"
      }
    ]
  }

  upgrade_vars = {
    upgrade_image       = var.upgrade_image
    upgrade_version     = var.upgrade_version
    pause_time          = var.upgrade_pause_time
    delay_time          = var.upgrade_delay_time
    eus_upgrade_version = var.eus_upgrade_version
    eus_upgrade_channel = var.eus_upgrade_channel
    eus_upgrade_image   = var.eus_upgrade_image
    eus_upstream        = var.eus_upstream
  }
}

resource "null_resource" "config" {

  triggers = {
    worker_count = length(var.worker_ips)
  }

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip[0]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "remote-exec" {
    inline = [
      "mkdir -p .openshift",
      "rm -rf ocp4-helpernode",
      "echo 'Cloning into ocp4-helpernode...'",
      "git clone ${var.helpernode_repo} --quiet",
      "cd ocp4-helpernode && git checkout ${var.helpernode_tag}"
    ]
  }
  provisioner "file" {
    content     = templatefile("${path.module}/templates/helpernode_inventory", local.helpernode_inventory)
    destination = "ocp4-helpernode/inventory"
  }
  provisioner "file" {
    content     = var.pull_secret
    destination = ".openshift/pull-secret"
  }
  provisioner "file" {
    content     = templatefile("${path.module}/templates/helpernode_vars.yaml", local.helpernode_vars)
    destination = "ocp4-helpernode/helpernode_vars.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "sed -i \"/^helper:.*/a \\ \\ networkifacename: $(ip r | grep \"${var.cidr} dev\" | awk '{print $3}')\" ocp4-helpernode/helpernode_vars.yaml",
      "echo 'Running ocp4-helpernode playbook...'",
      "cd ocp4-helpernode && ansible-playbook -e @helpernode_vars.yaml tasks/main.yml ${var.ansible_extra_options} --become"
    ]
  }
}

resource "null_resource" "configure_public_vip" {
  count      = var.bastion_count > 1 ? var.bastion_count : 0
  depends_on = [null_resource.config]

  triggers = {
    worker_count = length(var.worker_ips)
  }

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip[count.index]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "file" {
    content     = templatefile("${path.module}/templates/keepalived_vrrp_instance.tpl", local.public_vrrp)
    destination = "/tmp/keepalived_vrrp_instance"
  }
  provisioner "remote-exec" {
    inline = [
      # Set state=MASTER,priority=100 for first bastion and state=BACKUP,priority=90 for others.
      "sudo sed -i \"s/state <STATE>/state ${count.index == 0 ? "MASTER" : "BACKUP"}/\" /tmp/keepalived_vrrp_instance",
      "sudo sed -i \"s/priority <PRIORITY>/priority ${count.index == 0 ? "100" : "90"}/\" /tmp/keepalived_vrrp_instance",
      "sudo sed -i \"s/interface <INTERFACE>/interface $(ip r | grep ${var.public_cidr} | awk '{print $3}')/\" /tmp/keepalived_vrrp_instance",
      "sudo cat /tmp/keepalived_vrrp_instance >> /etc/keepalived/keepalived.conf",
      "sudo systemctl restart keepalived"
    ]
  }
}

resource "null_resource" "setup_snat" {
  count      = var.setup_snat ? var.bastion_count : 0
  depends_on = [null_resource.config]

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip[count.index]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "remote-exec" {
    inline = [<<EOF

echo "Configuring SNAT (experimental)..."

sudo firewall-cmd --zone=public --add-masquerade --permanent
# Masquerade will enable ip forwarding automatically
sudo firewall-cmd --reload

EOF
    ]
  }
}

resource "null_resource" "external_services" {
  count      = var.use_ibm_cloud_services ? var.bastion_count : 0
  depends_on = [null_resource.config, null_resource.setup_snat]

  triggers = {
    worker_count = length(var.worker_ips)
  }

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip[count.index]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Stopping HAPROXY and DNS'",
      "sudo systemctl stop haproxy.service && sudo systemctl stop named.service",
      "sudo systemctl mask haproxy.service && sudo systemctl mask named.service",
      "echo 'Changing DNS to external on bastion and dhcpd'",
      # TODO: This is hardcoded to 9.9.9.9 to use external nameserver. Need to read from dns_forwarders.
      "sudo sed -i 's/nameserver 127.0.0.1/nameserver 9.9.9.9/g' /etc/resolv.conf",
      "sudo sed -i 's/option domain-name-servers.*/option domain-name-servers 9.9.9.9;/g' /etc/dhcp/dhcpd.conf",
      "echo 'Adding static route for VPC subnet in dhcpd'",
      "sudo sed -i '/option routers/i option static-routes ${cidrhost(var.vpc_cidr, 0)} ${var.gateway_ip};' /etc/dhcp/dhcpd.conf",
      "sudo systemctl restart dhcpd.service"
    ]
  }
}

resource "null_resource" "pre_install" {
  count      = var.bastion_count
  depends_on = [null_resource.config, null_resource.configure_public_vip, null_resource.setup_snat, null_resource.external_services]

  triggers = {
    worker_count = length(var.worker_ips)
  }

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip[count.index]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  # DHCP config for setting MTU; Since helpernode DHCP template does not support MTU setting
  provisioner "remote-exec" {
    inline = [
      "sudo sed -i.mtubak '/option routers/i option interface-mtu ${var.private_network_mtu};' /etc/dhcp/dhcpd.conf",
      "sudo systemctl restart dhcpd.service"
    ]
  }
}

resource "null_resource" "install_config" {
  depends_on = [null_resource.pre_install]

  triggers = {
    worker_count = length(var.worker_ips)
  }

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip[0]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "remote-exec" {
    inline = [
      "rm -rf ocp4-playbooks",
      "echo 'Cloning into ocp4-playbooks...'",
      "git clone ${var.install_playbook_repo} --quiet",
      "cd ocp4-playbooks && git checkout ${var.install_playbook_tag}"
    ]
  }
  provisioner "file" {
    content     = templatefile("${path.module}/templates/install_inventory", local.install_inventory)
    destination = "ocp4-playbooks/inventory"
  }
  provisioner "file" {
    content     = templatefile("${path.module}/templates/install_vars.yaml", local.install_vars)
    destination = "ocp4-playbooks/install_vars.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "echo 'Running ocp install-config playbook...'",
      "cd ocp4-playbooks && ansible-playbook -i inventory -e @install_vars.yaml playbooks/install-config.yaml ${var.ansible_extra_options}"
    ]
  }
}


resource "ibm_pi_instance_action" "bootstrap_start" {
  depends_on = [null_resource.config, null_resource.pre_install, null_resource.install_config]
  count      = var.bootstrap_count == 0 ? 0 : 1

  pi_cloud_instance_id = var.service_instance_id
  pi_instance_id       = "${var.name_prefix}bootstrap"
  pi_action            = "start"
  pi_health_status     = "WARNING"
}

resource "null_resource" "bootstrap_config" {
  depends_on = [ibm_pi_instance_action.bootstrap_start]

  triggers = {
    worker_count = length(var.worker_ips)
  }

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip[0]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Running ocp bootstrap-config playbook...'",
      "cd ocp4-playbooks && ansible-playbook -i inventory -e @install_vars.yaml playbooks/bootstrap-config.yaml ${var.ansible_extra_options}"
    ]
  }
}



resource "null_resource" "powervs_config" {
  depends_on = [null_resource.install]
  count      = var.ibm_cloud_dl_endpoint_net_cidr != "" && var.ibm_cloud_http_proxy != "" ? 1 : 0

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip[0]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "file" {
    content     = templatefile("${path.module}/templates/powervs_config_vars.yaml", local.powervs_config_vars)
    destination = "ocp4-playbooks/powervs_config_vars.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "sed -i \"$ a ocp_node_net_intf: \\\"$(ip r | grep \"${var.cidr} dev\" | awk '{print $3}')\\\"\" ocp4-playbooks/powervs_config_vars.yaml",
      "echo 'Running powervs specific nodes configuration playbook...'",
      "cd ocp4-playbooks && ansible-playbook -i inventory -e @powervs_config_vars.yaml playbooks/powervs_config.yaml ${var.ansible_extra_options}"
    ]
  }
}

resource "null_resource" "upgrade" {
  depends_on = [null_resource.install, null_resource.powervs_config]
  count      = var.upgrade_version != "" || var.upgrade_image != "" || var.eus_upgrade_channel != "" || var.eus_upgrade_image != "" ? 1 : 0
  triggers = {
    upgrade_version     = var.upgrade_version
    upgrade_image       = var.upgrade_image
    eus_upgrade_version = var.eus_upgrade_version
    eus_upgrade_image   = var.eus_upgrade_image
  }

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip[0]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "file" {
    content     = templatefile("${path.module}/templates/upgrade_vars.yaml", local.upgrade_vars)
    destination = "ocp4-playbooks/upgrade_vars.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "echo 'Running ocp upgrade playbook...'",
      "cd ocp4-playbooks && ansible-playbook -i inventory -e @upgrade_vars.yaml playbooks/upgrade.yaml ${var.ansible_extra_options}"
    ]
  }
}





data "ibm_pi_catalog_images" "catalog_images" {
  pi_cloud_instance_id = var.service_instance_id
}

data "ibm_pi_network" "network" {
  pi_network_name      = var.network_name
  pi_cloud_instance_id = var.service_instance_id
}

data "ibm_pi_image" "worker" {
  count                = 1
  pi_image_name        = var.rhcos_image_name
  pi_cloud_instance_id = var.service_instance_id
}

data "ibm_pi_dhcps" "dhcp_services" {
  pi_cloud_instance_id = var.service_instance_id
}

# resource "ibm_pi_dhcp" "new_dhcp_service" {
#   count                = 1
#   pi_cloud_instance_id = var.service_instance_id
#   pi_cidr              = data.ibm_pi_network.network.cidr
#   pi_dns_server        = "8.8.8.8"
#   pi_dhcp_snat_enabled = true
#   # the pi_dhcp_name param will be prefixed by the DHCP ID when created, so keep it short here:
#   pi_dhcp_name = local.name_prefix
# }

# resource "ibm_pi_network" "public_network" {
#   pi_network_name      = "${local.name_prefix}-worker-pub-net"
#   pi_cloud_instance_id = var.service_instance_id
#   pi_network_type      = "pub-vlan"
#   pi_dns               = [for dns in split(";", var.dns_forwarders) : trimspace(dns)]
# }

locals {
  catalog_worker_image = [for x in data.ibm_pi_catalog_images.catalog_images.images : x if x.name == var.rhcos_image_name]
  worker_image_id      = length(local.catalog_worker_image) == 0 ? data.ibm_pi_image.worker[0].id : local.catalog_worker_image[0].image_id
  worker_storage_pool  = length(local.catalog_worker_image) == 0 ? data.ibm_pi_image.worker[0].storage_pool : local.catalog_worker_image[0].storage_pool
}

# Build the ignition file so it points back to the control plane
data "ignition_file" "w_hostname" {
  count     = var.worker["count"]
  overwrite = true
  mode      = "420" // 0644
  path      = "/etc/hostname"
  content {
    content = <<EOF
worker-${count.index}.ocp-power.xyz
EOF
  }
}

# Avoids a name resolution issue
data "ignition_file" "w_dns" {
  count     = var.worker["count"]
  overwrite = true
  mode      = "420" // 0644
  path      = "/etc/resolv.conf"
  content {
    content = templatefile("${path.module}/templates/resolv.tftpl", { ip_addrs = var.dns_forwarders })
  }
}

data "ignition_config" "worker" {
  count = var.worker["count"]
  merge {
    source = "https://${var.ignition_hostname}:22623/config/worker"
  }
  files = [
    data.ignition_file.w_hostname[count.index].rendered,
  data.ignition_file.w_dns[count.index].rendered]
}

# Modeled off the OpenShift Installer work for IPI PowerVS
# https://github.com/openshift/installer/blob/master/data/data/powervs/bootstrap/vm/main.tf#L41
# https://github.com/openshift/installer/blob/master/data/data/powervs/cluster/master/vm/main.tf
resource "ibm_pi_instance" "worker" {
  depends_on = [
    #ibm_pi_dhcp.new_dhcp_service,
    #ibm_pi_network.public_network
  ]
  count = var.worker["count"]

  pi_memory        = var.worker["memory"]
  pi_processors    = var.worker["processors"]
  pi_instance_name = "${local.name_prefix}-worker"

  pi_proc_type = var.processor_type
  pi_image_id  = local.worker_image_id
  pi_sys_type  = var.system_type

  pi_cloud_instance_id = var.service_instance_id
  pi_storage_pool      = local.worker_storage_pool

  #  pi_network {
  #    network_id = ibm_pi_network.public_network.network_id
  #  }
  pi_network {
    network_id = data.ibm_pi_network.network.id
    ip_address = "192.168.100.120"
  }

  pi_key_pair_name = var.public_key_name
  pi_health_status = "WARNING"

  pi_user_data = base64encode(data.ignition_config.worker[count.index].rendered)
}

# The PowerVS instance may take a few minutes to start (per the IPI work)
resource "time_sleep" "wait_3_minutes" {
  depends_on      = [ibm_pi_instance.worker]
  create_duration = "3m"
}

data "ibm_pi_instance_ip" "worker" {
  count      = 1
  depends_on = [time_sleep.wait_3_minutes]

  pi_instance_name     = ibm_pi_instance.worker[count.index].pi_instance_name
  pi_network_name      = data.ibm_pi_network.network.pi_network_name
  pi_cloud_instance_id = var.service_instance_id
}

data "ibm_pi_instance_ip" "worker_public_ip" {
  count      = 1
  depends_on = [time_sleep.wait_3_minutes]

  pi_instance_name     = ibm_pi_instance.worker[count.index].pi_instance_name
  pi_network_name      = data.ibm_pi_network.network.name
  pi_cloud_instance_id = var.service_instance_id
}



resource "null_resource" "powervs_config" {
  depends_on = [null_resource.install]
  count      = var.ibm_cloud_dl_endpoint_net_cidr != "" && var.ibm_cloud_http_proxy != "" ? 1 : 0

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip[0]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "file" {
    content     = templatefile("${path.module}/templates/powervs_config_vars.yaml", local.powervs_config_vars)
    destination = "ocp4-playbooks/powervs_config_vars.yaml"
  }
  provisioner "remote-exec" {
    inline = [
      "sed -i \"$ a ocp_node_net_intf: \\\"$(ip r | grep \"${var.cidr} dev\" | awk '{print $3}')\\\"\" ocp4-playbooks/powervs_config_vars.yaml",
      "echo 'Running powervs specific nodes configuration playbook...'",
      "cd ocp4-playbooks && ansible-playbook -i inventory -e @powervs_config_vars.yaml playbooks/powervs_config.yaml ${var.ansible_extra_options}"
    ]
  }
}


## May need to add it back
resource "null_resource" "pre_install" {
  count      = var.bastion_count
  depends_on = [null_resource.config, null_resource.configure_public_vip, null_resource.setup_snat, null_resource.external_services]

  triggers = {
    worker_count = length(var.worker_ips)
  }

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip[count.index]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  # DHCP config for setting MTU; Since helpernode DHCP template does not support MTU setting
  provisioner "remote-exec" {
    inline = [
      "sudo sed -i.mtubak '/option routers/i option interface-mtu ${var.private_network_mtu};' /etc/dhcp/dhcpd.conf",
      "sudo systemctl restart dhcpd.service"
    ]
  }
}

# https://github.com/ocp-power-automation/ocp4-playbooks/tree/main/playbooks/roles/powervs-nodes-config



resource "null_resource" "setup_snat" {
  count      = var.setup_snat ? var.bastion_count : 0
  depends_on = [null_resource.config]

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip[count.index]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "remote-exec" {
    inline = [<<EOF
echo "Configuring SNAT (experimental)..."

sudo firewall-cmd --zone=public --add-masquerade --permanent
# Masquerade will enable ip forwarding automatically
sudo firewall-cmd --reload
EOF
    ]
  }
}


resource "null_resource" "external_services" {
  count      = var.use_ibm_cloud_services ? var.bastion_count : 0
  depends_on = [null_resource.config]

  triggers = {
    worker_count = length(var.worker_ips)
  }

  connection {
    type        = "ssh"
    user        = var.rhel_username
    host        = var.bastion_public_ip[count.index]
    private_key = var.private_key
    agent       = var.ssh_agent
    timeout     = "${var.connection_timeout}m"
  }

  provisioner "remote-exec" {
    inline = [
      "echo 'Stopping HAPROXY and DNS'",
      "sudo systemctl stop haproxy.service && sudo systemctl stop named.service",
      "sudo systemctl mask haproxy.service && sudo systemctl mask named.service",
      "echo 'Changing DNS to external on bastion and dhcpd'",
      # TODO: This is hardcoded to 9.9.9.9 to use external nameserver. Need to read from dns_forwarders.
      "sudo sed -i 's/nameserver 127.0.0.1/nameserver 9.9.9.9/g' /etc/resolv.conf",
      "sudo sed -i 's/option domain-name-servers.*/option domain-name-servers 9.9.9.9;/g' /etc/dhcp/dhcpd.conf",
      "echo 'Adding static route for VPC subnet in dhcpd'",
      "sudo sed -i '/option routers/i option static-routes ${cidrhost(var.vpc_cidr, 0)} ${var.gateway_ip};' /etc/dhcp/dhcpd.conf",
      "sudo systemctl restart dhcpd.service"
    ]
  }
}


# resource "null_resource" "install_config" {
#   depends_on = [null_resource.pre_install]

#   triggers = {
#     worker_count = length(var.worker_ips)
#   }

#   connection {
#     type        = "ssh"
#     user        = var.rhel_username
#     host        = var.bastion_public_ip[0]
#     private_key = var.private_key
#     agent       = var.ssh_agent
#     timeout     = "${var.connection_timeout}m"
#   }

#   provisioner "remote-exec" {
#     inline = [
#       "rm -rf ocp4-playbooks",
#       "echo 'Cloning into ocp4-playbooks...'",
#       "git clone ${var.install_playbook_repo} --quiet",
#       "cd ocp4-playbooks && git checkout ${var.install_playbook_tag}"
#     ]
#   }
#   provisioner "file" {
#     content     = templatefile("${path.module}/templates/install_inventory", local.install_inventory)
#     destination = "ocp4-playbooks/inventory"
#   }
#   provisioner "file" {
#     content     = templatefile("${path.module}/templates/install_vars.yaml", local.install_vars)
#     destination = "ocp4-playbooks/install_vars.yaml"
#   }
#   provisioner "remote-exec" {
#     inline = [
#       "echo 'Running ocp install-config playbook...'",
#       "cd ocp4-playbooks && ansible-playbook -i inventory -e @install_vars.yaml playbooks/install-config.yaml ${var.ansible_extra_options}"
#     ]
#   }
# }
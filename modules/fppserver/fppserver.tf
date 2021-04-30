# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.


# some locals that I use to define paths for the remote ssh provisioners
locals {
  repo_script      = "/tmp/01_repo_setup.sh"
  mgmtdb_script_a  = "/tmp/02a_mgmtdb_removedb.sh"
  mgmtdb_script_b  = "/tmp/02b_mgmtdb_changeoh.sh"
  mgmtdb_script_c  = "/tmp/02c_mgmtdb_setup.sh"
  fpp_script       = "/tmp/03_fpp_setup.sh"
  dhclient_script  = "/tmp/dhclient.sh"
  dhclient_setup   = file("${path.module}/scripts/set-domain.sh")
}


###################################################
# data sources db_nodes and vnic to output the public_ip_address and hostname at the end of the deployment
data "oci_database_db_nodes" "fppll_db_nodes" {
    compartment_id = var.compartment_id
    db_system_id = oci_database_db_system.fppll_db_system[0].id
}

data "oci_core_vnic" "fppll_vnic" {
    vnic_id = data.oci_database_db_nodes.fppll_db_nodes.db_nodes[0].vnic_id
}

###################################################
# creation of the db_system. It is necessary to create a full db_system to bypass compute instance multicast limitation without strange hacks.
# the database itself is useless on the FPP server but might be interesting for testing purposes, therefore we give it a test name
resource "oci_database_db_system" "fppll_db_system" {
  count               = var.system_count
  availability_domain = var.availability_domain
  compartment_id      = var.compartment_id
  database_edition    = var.db_edition

  db_home {
    database {
      admin_password = var.db_admin_password
      db_name        = var.cdb_name
      character_set  = var.character_set
      ncharacter_set = var.n_character_set
      db_workload    = var.db_workload
      pdb_name       = var.pdb_name

      db_backup_config {
        auto_backup_enabled = false
      }
    }

    db_version   = var.db_version
    display_name = "fppll-fppsdbsys-${var.resId}"
  }

  db_system_options {
    storage_management = "ASM"
  }

  disk_redundancy         = var.db_disk_redundancy
  shape                   = var.db_system_shape
  subnet_id               = var.subnet_id
  ssh_public_keys         = [var.ssh_public_key , var.resUserPublicKey ]
  display_name            = "${var.fppserver_display_name}-${var.resId}"
  hostname                = "${var.fppserver_prefix}${format("%02d", count.index + 1)}"
  data_storage_size_in_gb = var.data_storage_size_in_gb
  license_model           = var.license_model
  node_count              = var.node_count
  nsg_ids                 = var.nsg_ids
  lifecycle {
    ignore_changes = [
      display_name, hostname,
    ]
  }
}


###################################################
# PROVISIONERS SECTION
# each remote execution must be atomic as those are not idempotent at all.
# Ansible provisioner would be a much better idea but not available everywhere.
###################################################

###################################################
# ssh provisioner #1: repo setup
data "template_file" "repo_setup" {
  template = file("${path.module}/scripts/01_repo_setup.sh")
}

resource "null_resource" "fpp_os_setup" {
  depends_on = [oci_database_db_system.fppll_db_system]

  provisioner "file" {
    content     = data.template_file.repo_setup.rendered
    destination = local.repo_script
    connection  {
      type        = "ssh"
      host        = data.oci_core_vnic.fppll_vnic.public_ip_address
      agent       = false
      timeout     = "5m"
      user        = var.vm_user
      private_key = var.ssh_private_key

    }
  }
  provisioner "remote-exec" {
    connection  {
      type        = "ssh"
      host        = data.oci_core_vnic.fppll_vnic.public_ip_address
      agent       = false
      timeout     = "30m"
      user        = var.vm_user
      private_key = var.ssh_private_key
    }
   
    inline = [
       "chmod +x ${local.repo_script}",
       "sudo ${local.repo_script}" ,
    ]
   }
}

###################################################
# ssh provisioner #2: remove existing DB
data "template_file" "mgmtdb_setup_a" {
  template = file("${path.module}/scripts/02a_mgmtdb_removedb.sh")
  vars = {
    pdb_name         = var.pdb_name
  }
}

resource "null_resource" "fpp_removedb" {
  depends_on = [null_resource.fpp_os_setup]

  provisioner "file" {
    content     = data.template_file.mgmtdb_setup_a.rendered
    destination = local.mgmtdb_script_a
    connection  {
      type        = "ssh"
      host        = data.oci_core_vnic.fppll_vnic.public_ip_address
      agent       = false
      timeout     = "5m"
      user        = var.vm_user
      private_key = var.ssh_private_key

    }
  }
  provisioner "remote-exec" {
    connection  {
      type        = "ssh"
      host        = data.oci_core_vnic.fppll_vnic.public_ip_address
      agent       = false
      timeout     = "30m"
      user        = var.vm_user
      private_key = var.ssh_private_key
    }
   
    inline = [
       "chmod +x ${local.mgmtdb_script_a}",
       "sudo -u oracle ${local.mgmtdb_script_a}",
    ]

   }
}

###################################################
# ssh provisioner #3: change OH
data "template_file" "mgmtdb_setup_b" {
  template = file("${path.module}/scripts/02b_mgmtdb_changeoh.sh")
}

resource "null_resource" "fpp_changeoh" {
  depends_on = [null_resource.fpp_removedb]

  provisioner "file" {
    content     = data.template_file.mgmtdb_setup_b.rendered
    destination = local.mgmtdb_script_b
    connection  {
      type        = "ssh"
      host        = data.oci_core_vnic.fppll_vnic.public_ip_address
      agent       = false
      timeout     = "5m"
      user        = var.vm_user
      private_key = var.ssh_private_key

    }
  }

  provisioner "remote-exec" {
    connection  {
      type        = "ssh"
      host        = data.oci_core_vnic.fppll_vnic.public_ip_address
      agent       = false
      timeout     = "30m"
      user        = var.vm_user
      private_key = var.ssh_private_key
    }
   
    inline = [
       "chmod +x ${local.mgmtdb_script_b}",
       "sudo ${local.mgmtdb_script_b}",
    ]

   }
}

###################################################
# ssh provisioner #4: create MGMTDB
data "template_file" "mgmtdb_setup_c" {
  template = file("${path.module}/scripts/02c_mgmtdb_setup.sh")
}

resource "null_resource" "fpp_mgmtdb_setup" {
  depends_on = [null_resource.fpp_changeoh]

  provisioner "file" {
    content     = data.template_file.mgmtdb_setup_c.rendered
    destination = local.mgmtdb_script_c
    connection  {
      type        = "ssh"
      host        = data.oci_core_vnic.fppll_vnic.public_ip_address
      agent       = false
      timeout     = "5m"
      user        = var.vm_user
      private_key = var.ssh_private_key

    }
  }

  provisioner "remote-exec" {
    connection  {
      type        = "ssh"
      host        = data.oci_core_vnic.fppll_vnic.public_ip_address
      agent       = false
      timeout     = "30m"
      user        = var.vm_user
      private_key = var.ssh_private_key
    }
   
    inline = [
       "chmod +x ${local.mgmtdb_script_c}",
       "sudo -u grid ${local.mgmtdb_script_c}",
    ]

   }
}

###################################################
# ssh provisioner #4: add and start FPP Server
data "template_file" "fpp_setup" {
  template = file("${path.module}/scripts/03_fpp_setup.sh")
  vars = {
    gns_ip         = cidrhost(var.subnet_cidr, var.gns_ip_offset)
  }

}
resource "null_resource" "fpp_provisioner" {
  depends_on = [null_resource.fpp_mgmtdb_setup]

  provisioner "file" {
    content     = data.template_file.fpp_setup.rendered
    destination = local.fpp_script
    connection  {
      type        = "ssh"
      host        = data.oci_core_vnic.fppll_vnic.public_ip_address
      agent       = false
      timeout     = "5m"
      user        = var.vm_user
      private_key = var.ssh_private_key

    }
  }

  provisioner "remote-exec" {
    connection  {
      type        = "ssh"
      host        = data.oci_core_vnic.fppll_vnic.public_ip_address
      agent       = false
      timeout     = "30m"
      user        = var.vm_user
      private_key = var.ssh_private_key
    }
   
    inline = [
       "chmod +x ${local.fpp_script}",
       "sudo ${local.fpp_script}"
    ]

   }
}

###################################################
# "parallel" provisioner: change the naming resolution so that it takes into account the subnet
resource "null_resource" "dhclient_resolv_setup" {
  depends_on = [oci_database_db_system.fppll_db_system, null_resource.fpp_os_setup]

  provisioner "file" {
    content     = "export PRESERVE_HOSTINFO=3"
    destination = "/tmp/oci-hostname.conf"
    connection  {
      type        = "ssh"
      host        = data.oci_core_vnic.fppll_vnic.public_ip_address
      agent       = false
      timeout     = "5m"
      user        = var.vm_user
      private_key = var.ssh_private_key

    }
  }
  provisioner "file" {
    content     = local.dhclient_setup
    destination = local.dhclient_script
    connection  {
      type        = "ssh"
      host        = data.oci_core_vnic.fppll_vnic.public_ip_address
      agent       = false
      timeout     = "5m"
      user        = var.vm_user
      private_key = var.ssh_private_key

    }
  }
  provisioner "remote-exec" {
    connection  {
      type        = "ssh"
      host        = data.oci_core_vnic.fppll_vnic.public_ip_address
      agent       = false
      timeout     = "1m"
      user        = var.vm_user
      private_key = var.ssh_private_key
    }
   
    inline = [
       "sudo mv ${local.dhclient_script} /etc/dhcp/dhclient-exit-hooks.d/set-domain.sh",
       "sudo mv /tmp/oci-hostname.conf /etc/oci-hostname.conf",
       "sudo chmod 644 /etc/oci-hostname.conf",
       "sudo chown root:root /etc/oci-hostname.conf",
       "sudo chmod 755 /etc/dhcp/dhclient-exit-hooks.d/set-domain.sh",
       "sudo new_ip_address=${data.oci_core_vnic.fppll_vnic.private_ip_address} reason=RENEW  /etc/dhcp/dhclient-exit-hooks.d/set-domain.sh"
    ]
   }
}

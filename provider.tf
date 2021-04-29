# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.
# ------------------------------------------------------------------------
# All the variables that are unique to your user / tenancy
# 
# If you fork from github, copy this file to "override.tf"
# so that your variables are not versioned publicly :-)
# override.tf is skipped by the .gitignore file
# ------------------------------------------------------------------------


# ----------------------------------
# Tenancy information
# ----------------------------------
variable "compartment_ocid" {
  description = "Your compartment OCID, eg: \"ocid1.compartment.oc1..aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\""
}
variable "tenancy_ocid" { 
  description = "Your tenancy OCID, eg: \"ocid1.tenancy.oc1..aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\""
}
variable "region" { 
  description = "Your region, eg: \"uk-london-1\""
}
variable "availability_domain_name" { 
  description = "Your availability domain, eg: \"OUGC:UK-LONDON-1-AD-1\""
}

# ----------------------------------
# OCI User information for API access
# ----------------------------------
variable "ociUserOcid" { 
  description = "Your compartment OCID, eg: \"ocid1.user.oc1..aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa\""
}
variable "fingerprint" { 
  description = "Your user fingerprint, eg: \"de:ad:be:ef:de:ad:be:ef:de:ad:be:ef:de:ad:be:ef\""
}
variable "private_key_path" { 
  description = "Path to your PEM key for OCI APIs, eg: \"~/.ssh/oci.pem\""
}

# ---------------------------------
# LiveLab specific:
# ---------------------------------

variable "resId" {
  description = "Reservations in livelab have a specific identifier. The green button will override this variable with that identifier."
  default = "1234"
}

variable "resUserPublicKey" {
  description = "LiveLab users will upload their public SSH key, this is what will be used to give them access as opc. For github users, this might be an additional public key for access as opc"
  default = ""
}


# -------------------------
# Setup the OCI provider...
# -------------------------
provider "oci" {
  tenancy_ocid = var.tenancy_ocid
  region = var.region
  user_ocid = var.ociUserOcid
  private_key_path = var.private_key_path
  fingerprint = var.fingerprint
}


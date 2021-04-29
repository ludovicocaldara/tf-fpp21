#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.

# !!!! RUN THIS PROCEDURE AT YOUR OWN RISK !!!!

# run as grid
# setup TDE wallets and hacks to create GIMR on OCI.

# ugly but effective hack: get the Oracle Home that is not CRS
export ORACLE_HOME=$(cat /u01/app/oraInventory/ContentsXML/inventory.xml | grep TYPE=\"O\" | grep -v CRS=\"true\" | awk '{print $3}' | awk -F\" '{print $2}')

# remove the current entry in sqlnet.ora for the wallet and add a new one:
sed -i /^ENCRYPTION_WALLET_LOCATION/d $(orabasehome)/network/admin/sqlnet.ora

cat <<EOF >> $(orabasehome)/network/admin/sqlnet.ora
ENCRYPTION_WALLET_LOCATION=(SOURCE=(METHOD=FILE)(METHOD_DATA=(DIRECTORY=/u01/app/oracle/wallets/mgmtdb)))
EOF
mkdir -p /u01/app/oracle/wallets/mgmtdb && chmod 700 /u01/app/oracle/wallets/mgmtdb


# first run of mgmtca (will fail for listener registration and missing view)
$ORACLE_HOME/bin/mgmtca createGIMRContainer -storageDiskLocation +DATA

export ORACLE_SID="-MGMTDB"
$ORACLE_HOME/bin/sqlplus / as sysdba <<EOF

  -- fix the listener registration
  ALTER SYSTEM SET LOCAL_LISTENER='$HOSTNAME:1526';
  ALTER SYSTEM REGISTER;

  -- fix the missing views
  @?/has/mgmtdb/sql/root/catclureppropsroot.sql

  -- create and open the keystore and set the master key (the password here is really bad)
  ADMINISTER KEY MANAGEMENT CREATE KEYSTORE '/u01/app/oracle/wallets/mgmtdb/' IDENTIFIED BY "Welcome123";
  ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY "Welcome123" ;
  ADMINISTER KEY MANAGEMENT SET KEY IDENTIFIED BY "Welcome123" WITH BACKUP;
EOF

# rerun mgmtca with the created views (will fail again for missing PDB TDE master key)
$ORACLE_HOME/bin/mgmtca createGIMRContainer -storageDiskLocation +DATA

$ORACLE_HOME/bin/sqlplus / as sysdba <<EOF
  alter session set container=GIMR_DSCREP_10;
  ADMINISTER KEY MANAGEMENT SET KEYSTORE OPEN IDENTIFIED BY Welcome123 ;
  ADMINISTER KEY MANAGEMENT SET KEY IDENTIFIED BY "Welcome123" WITH BACKUP;
EOF


# run the final mgmtca with just the schema deployment.
# note that this is run using the GI Home, not the DB Home...
GI_HOME=$(cat /etc/oracle/olr.loc 2>/dev/null | grep crs_home | awk -F= '{print $2}')
$GI_HOME/bin/mgmtca configRepos deploySchema


# last but not least, unlock our good old FPP metadata schema owner
$ORACLE_HOME/bin/sqlplus / as sysdba <<EOF
alter session set container=GIMR_DSCREP_10;
alter user ghsuser21 account unlock;
EOF

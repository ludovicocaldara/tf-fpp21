#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.

# !!!! RUN THIS PROCEDURE AT YOUR OWN RISK !!!!

# run this script as root to change the ownership of the Oracle Home to host the MGMTDB

# add group dba to grid
usermod -a -G dba grid

# ugly but effective hack: take the OH that is not CRS
ORACLE_HOME=$(cat /u01/app/oraInventory/ContentsXML/inventory.xml | grep TYPE=\"O\" | grep -v CRS=\"true\" | awk '{print $3}' | awk -F\" '{print $2}')

# change ORACLE_HOME ownership
chown -R grid /u01/app/oracle
sed -i s/^ORACLE_OWNER=oracle/ORACLE_OWNER=grid/ $ORACLE_HOME/install/utl/rootmacro.sh
$ORACLE_HOME/root.sh

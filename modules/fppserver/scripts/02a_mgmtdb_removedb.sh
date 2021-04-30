#!/bin/bash
# Copyright (c) 2021, Oracle and/or its affiliates. All rights reserved
# Licensed under the Universal Permissive License v 1.0 as shown at http://oss.oracle.com/licenses/upl.

# !!!! RUN THIS PROCEDURE AT YOUR OWN RISK !!!!

# run as user oracle: stop and remove the DB configured by the DBCS VM tooling.
# We use its Oracle Home to configure MGMTDB

# get GRID HOME
GI_HOME=$(cat /etc/oracle/olr.loc 2>/dev/null | grep crs_home | awk -F= '{print $2}')

# get DB_UNIQUE_NAME of the DBCS database
eval $($GI_HOME/bin/crsctl stat res -f -w "(TYPE = ora.database.type)" | grep DB_UNIQUE_NAME)

# ugly but effective hack: take the OH that is not CRS
export ORACLE_HOME=$(cat /u01/app/oraInventory/ContentsXML/inventory.xml | grep TYPE=\"O\" | grep -v CRS=\"true\" | awk '{print $3}' | awk -F\" '{print $2}')


# stop and remove the DB
$ORACLE_HOME/bin/srvctl stop database -database $DB_UNIQUE_NAME
$ORACLE_HOME/bin/srvctl remove database -database $DB_UNIQUE_NAME -noprompt

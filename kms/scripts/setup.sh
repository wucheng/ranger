#!/bin/bash
# Licensed to the Apache Software Foundation (ASF) under one or more
# contributor license agreements.  See the NOTICE file distributed with
# this work for additional information regarding copyright ownership.
# The ASF licenses this file to You under the Apache License, Version 2.0
# (the "License"); you may not use this file except in compliance with
# the License.  You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# -------------------------------------------------------------------------------------
#
# Ranger KMS Setup Script
#
# This script will install policymanager webapplication under tomcat and also, initialize the database with ranger users/tables.

PROPFILE=$PWD/install.properties
propertyValue=''

pidFolderName='/var/run/ranger_kms'
if [ ! -d "${pidFolderName}" ]; then
    mkdir -p "${pidFolderName}"
fi

if [ ! -f ${PROPFILE} ]
then
	echo "$PROPFILE file not found....!!";
	exit 1;
fi

usage() {
  [ "$*" ] && echo "$0: $*"
  sed -n '/^##/,/^$/s/^## \{0,1\}//p' "$0"
  exit 2
} 2>/dev/null

log() {
   local prefix="$(date +%Y-%m-%d\ %H:%M:%S,%3N) "
   echo "${prefix} $@" >> $LOGFILE
   echo "${prefix} $@"
}
#eval `grep -v '^XAAUDIT.' ${PROPFILE} | grep -v '^$' | grep -v '^#'`
get_prop(){
	validateProperty=$(sed '/^\#/d' $2 | grep "^$1\s*="  | tail -n 1) # for validation
	if  test -z "$validateProperty" ; then log "[E] '$1' not found in $2 file while getting....!!"; exit 1; fi
	value=$(echo $validateProperty | cut -d "=" -f2-)
	echo $value
}

PYTHON_COMMAND_INVOKER=$(get_prop 'PYTHON_COMMAND_INVOKER' $PROPFILE)
DB_FLAVOR=$(get_prop 'DB_FLAVOR' $PROPFILE)
SQL_CONNECTOR_JAR=$(get_prop 'SQL_CONNECTOR_JAR' $PROPFILE)
db_root_user=$(get_prop 'db_root_user' $PROPFILE)
db_root_password=$(get_prop 'db_root_password' $PROPFILE)
db_host=$(get_prop 'db_host' $PROPFILE)
db_name=$(get_prop 'db_name' $PROPFILE)
db_user=$(get_prop 'db_user' $PROPFILE)
db_password=$(get_prop 'db_password' $PROPFILE)
db_ssl_enabled=$(get_prop 'db_ssl_enabled' $PROPFILE)
db_ssl_required=$(get_prop 'db_ssl_required' $PROPFILE)
db_ssl_verifyServerCertificate=$(get_prop 'db_ssl_verifyServerCertificate' $PROPFILE)
KMS_MASTER_KEY_PASSWD=$(get_prop 'KMS_MASTER_KEY_PASSWD' $PROPFILE)
unix_user=$(get_prop 'unix_user' $PROPFILE)
unix_group=$(get_prop 'unix_group' $PROPFILE)
POLICY_MGR_URL=$(get_prop 'POLICY_MGR_URL' $PROPFILE)
REPOSITORY_NAME=$(get_prop 'REPOSITORY_NAME' $PROPFILE)
SSL_KEYSTORE_FILE_PATH=$(get_prop 'SSL_KEYSTORE_FILE_PATH' $PROPFILE)
SSL_KEYSTORE_PASSWORD=$(get_prop 'SSL_KEYSTORE_PASSWORD' $PROPFILE)
SSL_TRUSTSTORE_FILE_PATH=$(get_prop 'SSL_TRUSTSTORE_FILE_PATH' $PROPFILE)
SSL_TRUSTSTORE_PASSWORD=$(get_prop 'SSL_TRUSTSTORE_PASSWORD' $PROPFILE)
KMS_DIR=$(eval echo "$(get_prop 'KMS_DIR' $PROPFILE)")
app_home=$(eval echo "$(get_prop 'app_home' $PROPFILE)")
TMPFILE=$(eval echo "$(get_prop 'TMPFILE' $PROPFILE)")
LOGFILE=$(eval echo "$(get_prop 'LOGFILE' $PROPFILE)")
LOGFILES=$(eval echo "$(get_prop 'LOGFILES' $PROPFILE)")
JAVA_BIN=$(get_prop 'JAVA_BIN' $PROPFILE)
JAVA_VERSION_REQUIRED=$(get_prop 'JAVA_VERSION_REQUIRED' $PROPFILE)
JAVA_ORACLE=$(get_prop 'JAVA_ORACLE' $PROPFILE)
mysql_core_file=$(get_prop 'mysql_core_file' $PROPFILE)
oracle_core_file=$(get_prop 'oracle_core_file' $PROPFILE)
postgres_core_file=$(get_prop 'postgres_core_file' $PROPFILE)
sqlserver_core_file=$(get_prop 'sqlserver_core_file' $PROPFILE)
sqlanywhere_core_file=$(get_prop 'sqlanywhere_core_file' $PROPFILE)
cred_keystore_filename=$(eval echo "$(get_prop 'cred_keystore_filename' $PROPFILE)")
KMS_BLACKLIST_DECRYPT_EEK=$(get_prop 'KMS_BLACKLIST_DECRYPT_EEK' $PROPFILE)
RANGER_KMS_LOG_DIR=$(eval echo "$(get_prop 'RANGER_KMS_LOG_DIR' $PROPFILE)")
RANGER_KMS_PID_DIR_PATH=$(eval echo "$(get_prop 'RANGER_KMS_PID_DIR_PATH' $PROPFILE)")
HSM_TYPE=$(get_prop 'HSM_TYPE' $PROPFILE)
HSM_ENABLED=$(get_prop 'HSM_ENABLED' $PROPFILE)
HSM_PARTITION_NAME=$(get_prop 'HSM_PARTITION_NAME' $PROPFILE)
HSM_PARTITION_PASSWORD=$(get_prop 'HSM_PARTITION_PASSWORD' $PROPFILE)

kms_principal=$(get_prop 'kms_principal' $PROPFILE)
kms_keytab=$(get_prop 'kms_keytab' $PROPFILE)
hadoop_conf=$(get_prop 'hadoop_conf' $PROPFILE)

DB_HOST="${db_host}"

ranger_kms_http_enabled=$(get_prop 'ranger_kms_http_enabled' $PROPFILE)
ranger_kms_https_keystore_file=$(get_prop 'ranger_kms_https_keystore_file' $PROPFILE)
ranger_kms_https_keystore_keyalias=$(get_prop 'ranger_kms_https_keystore_keyalias' $PROPFILE)
ranger_kms_https_keystore_password=$(get_prop 'ranger_kms_https_keystore_password' $PROPFILE)

javax_net_ssl_keyStore=$(get_prop 'javax_net_ssl_keyStore' $PROPFILE)
javax_net_ssl_keyStorePassword=$(get_prop 'javax_net_ssl_keyStorePassword' $PROPFILE)
javax_net_ssl_trustStore=$(get_prop 'javax_net_ssl_trustStore' $PROPFILE)
javax_net_ssl_trustStorePassword=$(get_prop 'javax_net_ssl_trustStorePassword' $PROPFILE)

check_ret_status(){
	if [ $1 -ne 0 ]; then
		log "[E] $2";
		exit 1;
	fi
}

check_ret_status_for_groupadd(){
# 9 is the response if the group exists
    if [ $1 -ne 0 ] && [ $1 -ne 9 ]; then
        log "[E] $2";
        exit 1;
    fi
}

is_command () {
    log "[I] check if command $1 exists"
    type "$1" >/dev/null
}

get_distro(){
	log "[I] Checking distribution name.."
	ver=$(cat /etc/*{issues,release,version} 2> /dev/null)
	if [[ $(echo $ver | grep DISTRIB_ID) ]]; then
	    DIST_NAME=$(lsb_release -si)
	else
	    DIST_NAME=$(echo $ver | cut -d ' ' -f 1 | sort -u | head -1)
	fi
	export $DIST_NAME
	log "[I] Found distribution : $DIST_NAME"

}
#Get Properties from File without erroring out if property is not there
#$1 -> propertyName $2 -> fileName $3 -> variableName $4 -> failIfNotFound
getPropertyFromFileNoExit(){
	validateProperty=$(sed '/^\#/d' $2 | grep "^$1\s*="  | tail -n 1) # for validation
	if  test -z "$validateProperty" ; then 
		log "[E] '$1' not found in $2 file while getting....!!";
		if [ $4 == "true" ] ; then
		    exit 1;
		else
		    value=""
		fi
	else
	    value=$(echo $validateProperty | cut -d "=" -f2-)
	fi
	eval $3="'$value'"
}
#Get Properties from File
#$1 -> propertyName $2 -> fileName $3 -> variableName
getPropertyFromFile(){
	validateProperty=$(sed '/^\#/d' $2 | grep "^$1\s*="  | tail -n 1) # for validation
	if  test -z "$validateProperty" ; then log "[E] '$1' not found in $2 file while getting....!!"; exit 1; fi
	value=$(echo $validateProperty | cut -d "=" -f2-)
	eval $3="'$value'"
}

#Update Properties to File
#$1 -> propertyName $2 -> newPropertyValue $3 -> fileName
updatePropertyToFile(){
	sed -i 's@^'$1'=[^ ]*$@'$1'='$2'@g' $3
	#validate=`sed -i 's/^'$1'=[^ ]*$/'$1'='$2'/g' $3`	#for validation
	validate=$(sed '/^\#/d' $3 | grep "^$1"  | tail -n 1 | cut -d "=" -f2-) # for validation
	#echo 'V1:'$validate
	if test -z "$validate" ; then log "[E] '$1' not found in $3 file while Updating....!!"; exit 1; fi
	log "[I] File $3 Updated successfully : {'$1'}"
}

#Update Properties to File
#$1 -> propertyName $2 -> newPropertyValue $3 -> fileName
updatePropertyToFilePy(){
    python update_property.py $1 $2 $3
    check_ret_status $? "Update property failed for: {'$1'}"
}


init_logfiles () {
    for f in $LOGFILES; do
        touch $f
    done
}
password_validation() {
        if [ -z "$1" ]
        then
                log "[I] Blank password is not allowed for" $2". Please enter valid password."
                exit 1
        else
                if [[ $1 =~ [\"\'\`\\\] ]]
                then
                        log "[E]" $2 "password contains one of the unsupported special characters:\" ' \` \\"
                        exit 1
                else
                        log "[I]" $2 "password validated."
                fi
        fi
}
init_variables(){
	curDt=`date '+%Y%m%d%H%M%S'`

	if [ -f ${PWD}/version ] 
	then
		VERSION=`cat ${PWD}/version`
	else
		VERSION="0.5.0"
	fi

	KMS_DIR=$PWD

	RANGER_KMS=ranger-kms

	INSTALL_DIR=${KMS_DIR}

	WEBAPP_ROOT=${INSTALL_DIR}/ews/webapp

	DB_FLAVOR=`echo $DB_FLAVOR | tr '[:lower:]' '[:upper:]'`
	if [ "${DB_FLAVOR}" == "" ]
	then
		DB_FLAVOR="MYSQL"
	fi
	log "[I] DB_FLAVOR=${DB_FLAVOR}"
	########## HSM Config ##########

	propertyName=ranger.ks.hsm.enabled
	HSM_ENABLED=`echo $HSM_ENABLED | tr '[:lower:]' '[:upper:]'`
	password_validation "$KMS_MASTER_KEY_PASSWD" "KMS Master key"

	db_ssl_enabled=`echo $db_ssl_enabled | tr '[:upper:]' '[:lower:]'`
	if [ "${db_ssl_enabled}" != "true" ]
	then
		db_ssl_enabled="false"
		db_ssl_required="false"
		db_ssl_verifyServerCertificate="false"
	fi
	if [ "${db_ssl_enabled}" == "true" ]
	then
		db_ssl_required=`echo $db_ssl_required | tr '[:upper:]' '[:lower:]'`
		db_ssl_verifyServerCertificate=`echo $db_ssl_verifyServerCertificate | tr '[:upper:]' '[:lower:]'`
		if [ "${db_ssl_required}" != "true" ]
		then
			db_ssl_required="false"
		fi
		if [ "${db_ssl_verifyServerCertificate}" != "true" ]
		then
			db_ssl_verifyServerCertificate="false"
		fi
	fi
}


check_python_command() {
		if is_command ${PYTHON_COMMAND_INVOKER} ; then
			log "[I] '${PYTHON_COMMAND_INVOKER}' command found"
		else
			log "[E] '${PYTHON_COMMAND_INVOKER}' command not found"
		exit 1;
		fi
}

run_dba_steps(){
	getPropertyFromFileNoExit 'setup_mode' $PROPFILE setup_mode false
	if [ "x${setup_mode}x" == "xSeparateDBAx" ]; then
		log "[I] Setup mode is set to SeparateDBA. Not Running DBA steps. Please run dba_script.py before running setup..!";
	else
		log "[I] Setup mode is not set. Running DBA steps..";
                python dba_script.py -q
        fi
}
check_db_connector() {
	log "[I] Checking ${DB_FLAVOR} CONNECTOR FILE : ${SQL_CONNECTOR_JAR}"
	if test -f "$SQL_CONNECTOR_JAR"; then
		log "[I] ${DB_FLAVOR} CONNECTOR FILE : $SQL_CONNECTOR_JAR file found"
	else
		log "[E] ${DB_FLAVOR} CONNECTOR FILE : $SQL_CONNECTOR_JAR does not exists" ; exit 1;
	fi
}
check_java_version() {
	#Check for JAVA_HOME
	if [ "${JAVA_HOME}" == "" ]
	then
		log "[E] JAVA_HOME environment property not defined, aborting installation."
		exit 1
	fi

        export JAVA_BIN=${JAVA_HOME}/bin/java

	if is_command ${JAVA_BIN} ; then
		log "[I] '${JAVA_BIN}' command found"
	else
               log "[E] '${JAVA_BIN}' command not found"
               exit 1;
	fi

	version=$("$JAVA_BIN" -version 2>&1 | awk -F '"' '/version/ {print $2}')
	major=`echo ${version} | cut -d. -f1`
	minor=`echo ${version} | cut -d. -f2`
	if [[ "${major}" == 1 && "${minor}" < 7 ]] ; then
		log "[E] Java 1.7 is required, current java version is $version"
		exit 1;
	fi
}

sanity_check_files() {

	if test -d $app_home; then
		log "[I] $app_home folder found"
	else
		log "[E] $app_home does not exists" ; exit 1;
    fi
	if [ "${DB_FLAVOR}" == "MYSQL" ]
    then
		if test -f $mysql_core_file; then
			log "[I] $mysql_core_file file found"
		else
			log "[E] $mysql_core_file does not exists" ; exit 1;
		fi
	fi
	if [ "${DB_FLAVOR}" == "ORACLE" ]
    then
        if test -f ${oracle_core_file}; then
			log "[I] ${oracle_core_file} file found"
        else
            log "[E] ${oracle_core_file} does not exists" ; exit 1;
        fi
    fi
    if [ "${DB_FLAVOR}" == "POSTGRES" ]
    then
        if test -f ${postgres_core_file}; then
			log "[I] ${postgres_core_file} file found"
        else
            log "[E] ${postgres_core_file} does not exists" ; exit 1;
        fi
    fi
    if [ "${DB_FLAVOR}" == "MSSQL" ]
    then
        if test -f ${sqlserver_core_file}; then
			log "[I] ${sqlserver_core_file} file found"
        else
            log "[E] ${sqlserver_core_file} does not exists" ; exit 1;
        fi
    fi
	if [ "${DB_FLAVOR}" == "SQLA" ]
	then
		if [ "${LD_LIBRARY_PATH}" == "" ]
		then
			log "[E] LD_LIBRARY_PATH environment property not defined, aborting installation."
			exit 1
		fi
		if test -f ${sqlanywhere_core_file}; then
			log "[I] ${sqlanywhere_core_file} file found"
		else
			log "[E] ${sqlanywhere_core_file} does not exists" ; exit 1;
		fi
	fi
}

create_rollback_point() {
    DATE=`date`
    BAK_FILE=$APP-$VERSION.$DATE.bak
    log "Creating backup file : $BAK_FILE"
    cp "$APP" "$BAK_FILE"
}


copy_db_connector(){	
        libfolder=$PWD/ews/lib
	if [ ! -d  ${libfolder} ]
        then
                log "Creating ${libfolder}"
                mkdir -p ${libfolder}
        fi
	fn=`basename ${SQL_CONNECTOR_JAR}`
	if [ ! -f ${libfolder}/${fn} ]
	then
		log "[I] Copying ${DB_FLAVOR} Connector to ${libfolder} ";
    		cp -f $SQL_CONNECTOR_JAR ${libfolder}
		check_ret_status $? "Copying ${DB_FLAVOR} Connector to ${libfolder} failed"
		log "[I] Copying ${DB_FLAVOR} Connector to ${libfolder} DONE";
	else
		log "[I] Using already existing DB connector: ${libfolder}/${fn} ";
	fi
}

setup_kms(){
        #copying ranger kms provider 
	oldP=${PWD}
        cd $PWD/ews/webapp
        log "[I] Adding ranger kms provider as services in hadoop-common jar"
	for f in lib/hadoop-common*.jar
	do
        	 ${JAVA_HOME}/bin/jar -uf ${f}  META-INF/services/org.apache.hadoop.crypto.key.KeyProviderFactory
		chown ${unix_user}:${unix_group} ${f}
	done
        cd ${oldP}
}

update_properties() {
	newPropertyValue=''
	echo "export JAVA_HOME=${JAVA_HOME}" > ${WEBAPP_ROOT}/WEB-INF/classes/conf/java_home.sh
	chmod a+rx ${WEBAPP_ROOT}/WEB-INF/classes/conf/java_home.sh


	to_file=$PWD/ews/webapp/WEB-INF/classes/conf/dbks-site.xml
	if test -f $to_file; then
		log "[I] $to_file file found"
	else
		log "[E] $to_file does not exists" ; exit 1;
    fi

	if [ "${db_ssl_enabled}" != "" ]
	then
		propertyName=ranger.db.ssl.enabled
		newPropertyValue="${db_ssl_enabled}"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName=ranger.db.ssl.required
		newPropertyValue="${db_ssl_required}"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName=ranger.db.ssl.verifyServerCertificate
		newPropertyValue="${db_ssl_verifyServerCertificate}"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file
	fi

	if [ "${DB_FLAVOR}" == "MYSQL" ]
	then
		propertyName=ranger.ks.jpa.jdbc.url
		newPropertyValue="jdbc:log4jdbc:mysql://${DB_HOST}/${db_name}"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName=ranger.ks.jpa.jdbc.dialect
		newPropertyValue="org.eclipse.persistence.platform.database.MySQLPlatform"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName=ranger.ks.jpa.jdbc.driver
		newPropertyValue="net.sf.log4jdbc.DriverSpy"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

	fi
	if [ "${DB_FLAVOR}" == "ORACLE" ]
	then
		propertyName=ranger.ks.jpa.jdbc.url
		count=$(grep -o ":" <<< "$DB_HOST" | wc -l)
		#if [[ ${count} -eq 2 ]] ; then
		if [ ${count} -eq 2 ] || [ ${count} -eq 0 ]; then
			#jdbc:oracle:thin:@[HOST][:PORT]:SID or #jdbc:oracle:thin:@GL
			newPropertyValue="jdbc:oracle:thin:@${DB_HOST}"
		else
			#jdbc:oracle:thin:@//[HOST][:PORT]/SERVICE
			newPropertyValue="jdbc:oracle:thin:@//${DB_HOST}"
		fi
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName=ranger.ks.jpa.jdbc.dialect
		newPropertyValue="org.eclipse.persistence.platform.database.OraclePlatform"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName=ranger.ks.jpa.jdbc.driver
		newPropertyValue="oracle.jdbc.OracleDriver"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

	fi
	if [ "${DB_FLAVOR}" == "POSTGRES" ]
	then
		db_name=`echo ${db_name} | tr '[:upper:]' '[:lower:]'`
		db_user=`echo ${db_user} | tr '[:upper:]' '[:lower:]'`

		propertyName=ranger.ks.jpa.jdbc.url
		newPropertyValue="jdbc:postgresql://${DB_HOST}/${db_name}"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName=ranger.ks.jpa.jdbc.dialect
		newPropertyValue="org.eclipse.persistence.platform.database.PostgreSQLPlatform"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName=ranger.ks.jpa.jdbc.driver
		newPropertyValue="org.postgresql.Driver"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

	fi
	if [ "${DB_FLAVOR}" == "MSSQL" ]
	then
		propertyName=ranger.ks.jpa.jdbc.url
		newPropertyValue="jdbc:sqlserver://${DB_HOST};databaseName=${db_name}"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName=ranger.ks.jpa.jdbc.dialect
		newPropertyValue="org.eclipse.persistence.platform.database.SQLServerPlatform"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName=ranger.ks.jpa.jdbc.driver
		newPropertyValue="com.microsoft.sqlserver.jdbc.SQLServerDriver"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

	fi
	if [ "${DB_FLAVOR}" == "SQLA" ]
	then
		propertyName=ranger.ks.jpa.jdbc.url
		newPropertyValue="jdbc:sqlanywhere:database=${db_name};host=${DB_HOST}"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName=ranger.ks.jpa.jdbc.dialect
		newPropertyValue="org.eclipse.persistence.platform.database.SQLAnywherePlatform"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName=ranger.ks.jpa.jdbc.driver
		newPropertyValue="sap.jdbc4.sqlanywhere.IDriver"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file
	fi
	propertyName=ranger.ks.jpa.jdbc.user
	newPropertyValue="${db_user}"
	updatePropertyToFilePy $propertyName $newPropertyValue $to_file

	keystore="${cred_keystore_filename}"

	echo "Starting configuration for XA DB credentials:"

	MK_CREDENTIAL_ATTR="ranger.db.encrypt.key.password"
	DB_CREDENTIAL_ATTR="ranger.ks.jpa.jdbc.password" 

	MK_CREDENTIAL_ALIAS="ranger.ks.masterkey.password"
	DB_CREDENTIAL_ALIAS="ranger.ks.jpa.jdbc.credential.alias"

	HSM_PARTITION_PASSWD="ranger.ks.hsm.partition.password"
	HSM_PARTITION_PASSWORD_ALIAS="ranger.kms.hsm.partition.password"

        HSM_ENABLED=`echo $HSM_ENABLED | tr '[:lower:]' '[:upper:]'`

	if [ "${keystore}" != "" ]
	then
		mkdir -p `dirname "${keystore}"`

		$PYTHON_COMMAND_INVOKER ranger_credential_helper.py -l "cred/lib/*" -f "$keystore" -k "${DB_CREDENTIAL_ALIAS}" -v "${db_password}" -c 1
		$PYTHON_COMMAND_INVOKER ranger_credential_helper.py -l "cred/lib/*" -f "$keystore" -k "${MK_CREDENTIAL_ALIAS}" -v "${KMS_MASTER_KEY_PASSWD}" -c 1
		#$JAVA_HOME/bin/java -cp "cred/lib/*" org.apache.ranger.credentialapi.buildks create "${DB_CREDENTIAL_ALIAS}" -value "$db_password" -provider jceks://file$keystore
		#$JAVA_HOME/bin/java -cp "cred/lib/*" org.apache.ranger.credentialapi.buildks create "${MK_CREDENTIAL_ALIAS}" -value "${KMS_MASTER_KEY_PASSWD}" -provider jceks://file$keystore

		if [ "${HSM_ENABLED}" == "TRUE" ]
                then
                        password_validation "$HSM_PARTITION_PASSWORD" "HSM Partition Password"

                        $PYTHON_COMMAND_INVOKER ranger_credential_helper.py -l "cred/lib/*" -f "$keystore" -k "${HSM_PARTITION_PASSWORD_ALIAS}" -v "${HSM_PARTITION_PASSWORD}" -c 1
                       
                        propertyName=ranger.ks.hsm.partition.password.alias
                        newPropertyValue="${HSM_PARTITION_PASSWORD_ALIAS}"
                        updatePropertyToFilePy $propertyName $newPropertyValue $to_file
                       
                        propertyName=ranger.ks.hsm.partition.password
                        newPropertyValue="_"
                        updatePropertyToFilePy $propertyName $newPropertyValue $to_file
                fi

		propertyName=ranger.ks.jpa.jdbc.credential.alias
		newPropertyValue="${DB_CREDENTIAL_ALIAS}"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName=ranger.ks.jpa.jdbc.credential.provider.path
		newPropertyValue="${keystore}"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName=ranger.ks.jpa.jdbc.password
		newPropertyValue="_"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName=ranger.ks.masterkey.credential.alias
	        newPropertyValue="${MK_CREDENTIAL_ALIAS}"
                updatePropertyToFilePy $propertyName $newPropertyValue $to_file

                propertyName=ranger.db.encrypt.key.password
                newPropertyValue="_"
                updatePropertyToFilePy $propertyName $newPropertyValue $to_file
	else
		propertyName="${DB_CREDENTIAL_ATTR}"
		newPropertyValue="${db_password}"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName="${MK_CREDENTIAL_ATTR}"
		newPropertyValue="${KMS_MASTER_KEY_PASSWD}"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName="${HSM_PARTITION_PASSWD}"
                newPropertyValue="${HSM_PARTITION_PASSWORD}"
                updatePropertyToFilePy $propertyName $newPropertyValue $to_file
	fi

	if test -f $keystore; then
		#echo "$keystore found."
		chown -R ${unix_user}:${unix_group} ${keystore}
		chmod 640 ${keystore}
	else
		#echo "$keystore not found. so clear text password"

		propertyName="${DB_CREDENTIAL_ATTR}"
		newPropertyValue="${db_password}"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName="${MK_CREDENTIAL_ATTR}"
		newPropertyValue="${KMS_MASTER_KEY_PASSWD}"
		updatePropertyToFilePy $propertyName $newPropertyValue $to_file

		propertyName="${HSM_PARTITION_PASSWD}"
                newPropertyValue="${HSM_PARTITION_PASSWORD}"
                updatePropertyToFilePy $propertyName $newPropertyValue $to_file
	fi

	propertyName=hadoop.kms.blacklist.DECRYPT_EEK
        newPropertyValue="${KMS_BLACKLIST_DECRYPT_EEK}"
        updatePropertyToFilePy $propertyName $newPropertyValue $to_file

	########### KERBEROS CONFIG ############

	if [ "${kms_principal}" != "" ]
	then
		propertyName=ranger.ks.kerberos.principal
        	newPropertyValue="${kms_principal}"
	        updatePropertyToFilePy $propertyName $newPropertyValue $to_file
	fi

	if [ "${kms_keytab}" != "" ]
	then
		propertyName=ranger.ks.kerberos.keytab
        	newPropertyValue="${kms_keytab}"
	        updatePropertyToFilePy $propertyName $newPropertyValue $to_file
	fi

	########### HSM CONFIG #################
       
       
        if [ "${HSM_ENABLED}" != "TRUE" ]
        then
                propertyName=ranger.ks.hsm.enabled
                newPropertyValue="false"
                updatePropertyToFilePy $propertyName $newPropertyValue $to_file
        else
                propertyName=ranger.ks.hsm.enabled
                newPropertyValue="true"
                updatePropertyToFilePy $propertyName $newPropertyValue $to_file

                propertyName=ranger.ks.hsm.type
                newPropertyValue="${HSM_TYPE}"
                updatePropertyToFilePy $propertyName $newPropertyValue $to_file
       
                propertyName=ranger.ks.hsm.partition.name
                newPropertyValue="${HSM_PARTITION_NAME}"
                updatePropertyToFilePy $propertyName $newPropertyValue $to_file         
        fi

	to_file_kms_site=$PWD/ews/webapp/WEB-INF/classes/conf/ranger-kms-site.xml
    if test -f $to_file_kms_site; then
		log "[I] $to_file_kms_site file found"
	else
		log "[E] $to_file_kms_site does not exists" ; exit 1;
    fi

	propertyName=ranger.service.http.enabled
	newPropertyValue="${ranger_kms_http_enabled}"
	updatePropertyToFilePy $propertyName $newPropertyValue $to_file_kms_site
	if [ "${ranger_kms_http_enabled}" == "false" ]
	then
		if [ "${ranger_kms_https_keystore_keyalias}" == "" ]
		then
			ranger_kms_https_keystore_keyalias=rangerkms
		fi
		if [ "${ranger_kms_https_keystore_file}" != "" ] && [ "${ranger_kms_https_keystore_password}" != "" ]
		then
			propertyName=ranger.service.https.attrib.ssl.enabled
			newPropertyValue="true"
			updatePropertyToFilePy $propertyName $newPropertyValue $to_file_kms_site

			propertyName=ranger.service.https.attrib.client.auth
			newPropertyValue="want"
			updatePropertyToFilePy $propertyName $newPropertyValue $to_file_kms_site

			propertyName=ranger.service.https.attrib.keystore.file
			newPropertyValue="${ranger_kms_https_keystore_file}"
			updatePropertyToFilePy $propertyName $newPropertyValue $to_file_kms_site

			propertyName=ranger.service.https.attrib.keystore.keyalias
			newPropertyValue="${ranger_kms_https_keystore_keyalias}"
			updatePropertyToFilePy $propertyName $newPropertyValue $to_file_kms_site

			policymgr_https_keystore_credential_alias=keyStoreCredentialAlias
			propertyName=ranger.service.https.attrib.keystore.credential.alias
			newPropertyValue="${policymgr_https_keystore_credential_alias}"
			updatePropertyToFilePy $propertyName $newPropertyValue $to_file_kms_site

			propertyName=ranger.credential.provider.path
			newPropertyValue="${keystore}"
			updatePropertyToFilePy $propertyName $newPropertyValue $to_file_kms_site

			if [ "${keystore}" != "" ]
			then
				propertyName=ranger.service.https.attrib.keystore.pass
				newPropertyValue="_"
				updatePropertyToFilePy $propertyName $newPropertyValue $to_file_kms_site
				$PYTHON_COMMAND_INVOKER ranger_credential_helper.py -l "cred/lib/*" -f "$keystore" -k "$policymgr_https_keystore_credential_alias" -v "$ranger_kms_https_keystore_password" -c 1
			else
				propertyName=ranger.service.https.attrib.keystore.pass
				newPropertyValue="${ranger_kms_https_keystore_password}"
				updatePropertyToFilePy $propertyName $newPropertyValue $to_file_kms_site
			fi
			if test -f $keystore; then
				chown -R ${unix_user}:${unix_group} ${keystore}
				chmod 640 ${keystore}
			else
				propertyName=ranger.service.https.attrib.keystore.pass
				newPropertyValue="${ranger_kms_https_keystore_password}"
				updatePropertyToFilePy $propertyName $newPropertyValue $to_file_kms_site
			fi
		fi
	fi
}

#=====================================================================

setup_unix_user_group(){
	log "[I] Setting up UNIX user : ${unix_user} and group: ${unix_group}";
	#create group if it does not exist
	egrep "^$unix_group" /etc/group >& /dev/null
	if [ $? -ne 0 ]
	then
		groupadd ${unix_group}
		check_ret_status_for_groupadd $? "Creating group ${unix_group} failed"
	fi

	id -u ${unix_user} > /dev/null 2>&1

	if [ $? -ne 0 ]
	then
	    log "[I] Creating new user and adding to group";
        useradd ${unix_user} -g ${unix_group} -m
		check_ret_status $? "useradd ${unix_user} failed"
	else
	    log "[I] User already exists, adding it to group";
	    usermod -g ${unix_group} ${unix_user}
	fi

	log "[I] Setting up UNIX user : ${unix_user} and group: ${unix_group} DONE";
}

setup_install_files(){

	log "[I] Setting up installation files and directory";

	if [ ! -d ${WEBAPP_ROOT}/WEB-INF/classes/conf ]; then
	    log "[I] Copying ${WEBAPP_ROOT}/WEB-INF/classes/conf.dist ${WEBAPP_ROOT}/WEB-INF/classes/conf"
	    mkdir -p ${WEBAPP_ROOT}/WEB-INF/classes/conf
	    cp ${WEBAPP_ROOT}/WEB-INF/classes/conf.dist/* ${WEBAPP_ROOT}/WEB-INF/classes/conf
	fi
	if [ -d ${WEBAPP_ROOT}/WEB-INF/classes/conf ]; then
        chown -R ${unix_user} ${WEBAPP_ROOT}/WEB-INF/classes/conf
        chown -R ${unix_user} ${WEBAPP_ROOT}/WEB-INF/classes/conf/
	fi

	if [ ! -d ${WEBAPP_ROOT}/WEB-INF/classes/lib ]; then
	    log "[I] Creating ${WEBAPP_ROOT}/WEB-INF/classes/lib"
	    mkdir -p ${WEBAPP_ROOT}/WEB-INF/classes/lib
	fi
	if [ -d ${WEBAPP_ROOT}/WEB-INF/classes/lib ]; then
		chown -R ${unix_user} ${WEBAPP_ROOT}/WEB-INF/classes/lib
	fi

	echo "export RANGER_HADOOP_CONF_DIR=${hadoop_conf}" > ${WEBAPP_ROOT}/WEB-INF/classes/conf/ranger-kms-env-hadoopconfdir.sh
        chmod a+rx ${WEBAPP_ROOT}/WEB-INF/classes/conf/ranger-kms-env-hadoopconfdir.sh

        hadoop_conf_file=${hadoop_conf}/core-site.xml
        ranger_hadoop_conf_file=${WEBAPP_ROOT}/WEB-INF/classes/conf/core-site.xml

        if [ -d ${WEBAPP_ROOT}/WEB-INF/classes/conf ]; then
                chown -R ${unix_user} ${WEBAPP_ROOT}/WEB-INF/classes/conf
                if [ "${hadoop_conf}" == "" ]
                then
                        log "[WARN] Property hadoop_conf not found. Creating blank core-site.xml."
                        echo "<configuration></configuration>" > ${WEBAPP_ROOT}/WEB-INF/classes/conf/core-site.xml
                else
                        if [ -f ${hadoop_conf_file} ]; then
                                ln -sf ${hadoop_conf_file} ${WEBAPP_ROOT}/WEB-INF/classes/conf/core-site.xml
                        else
                                log "[WARN] core-site.xml file not found in provided hadoop_conf path. Creating blank core-site.xml"
                                echo "<configuration></configuration>" > ${WEBAPP_ROOT}/WEB-INF/classes/conf/core-site.xml
                        fi
                fi
        fi

	if [ -d /etc/init.d ]; then
	    log "[I] Setting up init.d"
	    cp ${INSTALL_DIR}/${RANGER_KMS}-initd /etc/init.d/${RANGER_KMS}
	    chmod ug+rx /etc/init.d/${RANGER_KMS}

	    if [ -d /etc/rc2.d ]
	    then
		RC_DIR=/etc/rc2.d
		log "[I] Creating script S88${RANGER_KMS}/K90${RANGER_KMS} in $RC_DIR directory .... "
		rm -f $RC_DIR/S88${RANGER_KMS}  $RC_DIR/K90${RANGER_KMS}
		ln -s /etc/init.d/${RANGER_KMS} $RC_DIR/S88${RANGER_KMS}
		ln -s /etc/init.d/${RANGER_KMS} $RC_DIR/K90${RANGER_KMS}
	    fi

	    if [ -d /etc/rc3.d ]
	    then
		RC_DIR=/etc/rc3.d
		log "[I] Creating script S88${RANGER_KMS}/K90${RANGER_KMS} in $RC_DIR directory .... "
		rm -f $RC_DIR/S88${RANGER_KMS}  $RC_DIR/K90${RANGER_KMS}
		ln -s /etc/init.d/${RANGER_KMS} $RC_DIR/S88${RANGER_KMS}
		ln -s /etc/init.d/${RANGER_KMS} $RC_DIR/K90${RANGER_KMS}
	    fi

	    # SUSE has rc2.d and rc3.d under /etc/rc.d
	    if [ -d /etc/rc.d/rc2.d ]
	    then
		RC_DIR=/etc/rc.d/rc2.d
		log "[I] Creating script S88${RANGER_KMS}/K90${RANGER_KMS} in $RC_DIR directory .... "
		rm -f $RC_DIR/S88${RANGER_KMS}  $RC_DIR/K90${RANGER_KMS}
		ln -s /etc/init.d/${RANGER_KMS} $RC_DIR/S88${RANGER_KMS}
		ln -s /etc/init.d/${RANGER_KMS} $RC_DIR/K90${RANGER_KMS}
	    fi
	    if [ -d /etc/rc.d/rc3.d ]
	    then
		RC_DIR=/etc/rc.d/rc3.d
		log "[I] Creating script S88${RANGER_KMS}/K90${RANGER_KMS} in $RC_DIR directory .... "
		rm -f $RC_DIR/S88${RANGER_KMS}  $RC_DIR/K90${RANGER_KMS}
		ln -s /etc/init.d/${RANGER_KMS} $RC_DIR/S88${RANGER_KMS}
		ln -s /etc/init.d/${RANGER_KMS} $RC_DIR/K90${RANGER_KMS}
	    fi
	fi
	if [  -f /etc/init.d/${RANGER_KMS} ]; then
		if [ "${unix_user}" != "" ]; then
			sed  's/^LINUX_USER=.*$/LINUX_USER='${unix_user}'/g' -i  /etc/init.d/${RANGER_KMS}
		fi
	fi

    	if [ -z "${RANGER_KMS_LOG_DIR}" ] || [ ${RANGER_KMS_LOG_DIR} == ${KMS_DIR} ]; then
        	RANGER_KMS_LOG_DIR=${KMS_DIR}/ews/logs;
	fi	
        if [ ! -d ${RANGER_KMS_LOG_DIR} ]; then
            log "[I] ${RANGER_KMS_LOG_DIR} Ranger KMS Log folder"
            mkdir -p ${RANGER_KMS_LOG_DIR}
        fi
        if [ -d ${RANGER_KMS_LOG_DIR} ]; then
            chown -R ${unix_user} ${RANGER_KMS_LOG_DIR}
        fi
        echo "export RANGER_KMS_LOG_DIR=${RANGER_KMS_LOG_DIR}" > ${WEBAPP_ROOT}/WEB-INF/classes/conf/ranger-kms-env-logdir.sh
    	chmod a+rx ${WEBAPP_ROOT}/WEB-INF/classes/conf/ranger-kms-env-logdir.sh

        if [ ! -d ${RANGER_KMS_PID_DIR_PATH} ]; then
                log "[I] Creating KMS PID folder: ${RANGER_KMS_PID_DIR_PATH}"
                mkdir -p ${RANGER_KMS_PID_DIR_PATH}
        fi
        if [ -d ${RANGER_KMS_PID_DIR_PATH} ]; then
                chown -R ${unix_user} ${RANGER_KMS_PID_DIR_PATH}
        fi
        echo "export RANGER_KMS_PID_DIR_PATH=${RANGER_KMS_PID_DIR_PATH}" > ${WEBAPP_ROOT}/WEB-INF/classes/conf/ranger-kms-env-piddir.sh
        echo "export KMS_USER=${unix_user}" >> ${WEBAPP_ROOT}/WEB-INF/classes/conf/ranger-kms-env-piddir.sh
        chmod a+rx ${WEBAPP_ROOT}/WEB-INF/classes/conf/ranger-kms-env-piddir.sh

	if [ "${db_ssl_verifyServerCertificate}" == "true" ]
	then
		DB_SSL_PARAM="' -Djavax.net.ssl.keyStore=${javax_net_ssl_keyStore} -Djavax.net.ssl.keyStorePassword=${javax_net_ssl_keyStorePassword} -Djavax.net.ssl.trustStore=${javax_net_ssl_trustStore} -Djavax.net.ssl.trustStorePassword=${javax_net_ssl_trustStorePassword} '"
		echo "export DB_SSL_PARAM=${DB_SSL_PARAM}" > ${WEBAPP_ROOT}/WEB-INF/classes/conf/ranger-kms-env-dbsslparam.sh
        chmod a+rx ${WEBAPP_ROOT}/WEB-INF/classes/conf/ranger-kms-env-dbsslparam.sh
    else
		if [ -f ${WEBAPP_ROOT}/WEB-INF/classes/conf/ranger-kms-env-dbsslparam.sh ]; then
			DB_SSL_PARAM=""
			echo "export DB_SSL_PARAM=${DB_SSL_PARAM}" > ${WEBAPP_ROOT}/WEB-INF/classes/conf/ranger-kms-env-dbsslparam.sh
			chmod a+rx ${WEBAPP_ROOT}/WEB-INF/classes/conf/ranger-kms-env-dbsslparam.sh
		fi
	fi
	log "[I] Setting up installation files and directory DONE";

	if [ ! -f ${INSTALL_DIR}/rpm ]; then
	    if [ -d ${INSTALL_DIR} ]
	    then
		chown -R ${unix_user}:${unix_group} ${INSTALL_DIR}
		chown -R ${unix_user}:${unix_group} ${INSTALL_DIR}/*
	    fi
	fi

	# Copy ranger-kms-services to /usr/bin
	if [ ! \( -e /usr/bin/ranger-kms \) ]
	then
	  ln -sf ${INSTALL_DIR}/ranger-kms /usr/bin/ranger-kms
	  chmod ug+rx /usr/bin/ranger-kms	
	fi

	if [ ! \( -e /usr/bin/ranger-kms-services.sh \) ]
	then
	  ln -sf ${INSTALL_DIR}/ranger-kms /usr/bin/ranger-kms-services.sh
	  chmod ug+rx /usr/bin/ranger-kms-services.sh	
	fi

	if [ ! \( -e ${INSTALL_DIR}/ranger-kms-services.sh \) ]
	then
	  ln -sf ${INSTALL_DIR}/ranger-kms-initd ${INSTALL_DIR}/ranger-kms-services.sh
	  chmod ug+rx ${INSTALL_DIR}/ranger-kms-services.sh	
	fi
	if [ ! -d /var/log/ranger/kms ]; then
		mkdir -p /var/log/ranger/kms
		if [ -d ews/logs ]; then
			cp -r ews/logs/* /var/log/ranger/kms
		fi
	fi
	if [ -d /var/log/ranger/kms ]; then
		chmod 755 /var/log/ranger/kms
        chown -R $unix_user:$unix_group /var/log/ranger/kms
	fi

}

init_logfiles
log " --------- Running Ranger KMS Application Install Script --------- "
log "[I] uname=`uname`"
log "[I] hostname=`hostname`"
init_variables
get_distro
check_java_version
check_db_connector
setup_unix_user_group
setup_install_files
sanity_check_files
copy_db_connector
check_python_command
run_dba_steps
if [ "$?" == "0" ]
then
	$PYTHON_COMMAND_INVOKER db_setup.py
else
	exit 1
fi
if [ "$?" == "0" ]
then
	update_properties
	$PYTHON_COMMAND_INVOKER db_setup.py -javapatch
    setup_kms
else
	log "[E] DB schema setup failed! Please contact Administrator."
	exit 1
fi

./enable-kms-plugin.sh
if [ "$?" != "0" ]
then
        exit 1
fi
echo "Installation of Ranger KMS is completed."

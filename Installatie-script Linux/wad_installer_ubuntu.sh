#!/bin/bash

############################################################################################
# Configuration of installation paths, etc
############################################################################################

TARGET_DCM4CHEE=/opt
TARGET_WAD_SERVICES=/opt
TARGET_XML=/opt
TARGET_WAD_INTERFACE=/var/www
TARGET_STARTSCRIPT=/usr/local/bin

ZIP_DCM4CHEE=source/dcm4chee-2.17.1-mysql.zip
ZIP_DCM4CHEE_ARR=source/dcm4chee-arr-3.0.11-mysql.zip
#ZIP_DCM4CHEE_CDW=source/dcm4chee-cdw-2.17.0.zip
#ZIP_DCM4CHEE_WEB=source/dcm4chee-web-3.0.3-mysql.zip
ZIP_JBOSS=source/jboss-4.2.3.GA-jdk6.zip


############################################################################################
############################################################################################

## This script installs the WAD software for Linux
## Check dependencies:

if [ "$(id -u)" != "0" ]; then
   echo "This script must be run as root or using sudo" 1>&2
   exit 1
fi

distro=$(lsb_release -i | awk '{print $3}')

if [ "$distro" != "Ubuntu" ]; then
	echo "sorry, this script is currently only supported for Ubuntu!"
	exit 1
fi


############################################################################################
# Ask for Mysql root password
############################################################################################

echo
echo "Please provide your Mysql root-password: "
read -s -p "Please provide your Mysql root-password: " mysqlpwd
echo

############################################################################################
# Install jdk/jre
############################################################################################

echo "Detected java version: "
echo
[ -f /usr/bin/java ] && java -version
echo

if [ -f /usr/bin/java ]; then
        echo
        read -n 1 -p "Skip installing java jre/jdk? [Y/n] " yesno
fi

if [[ "$yesno" != "" && "$yesno" != "y" && "$yesno" != "Y" ]] ; then
        echo
        echo "1. none"
        echo "2. openjdk-6-jdk"
        echo "3. openjdk-6-jre"
        echo "4. openjdk-7-jdk"
        echo "5. openjdk-7-jre"

        read -n 1 -p "Which version of java do you want to install? " option
        if [ $option == "2" ]; then
                JAVA=openjdk-6-jdk
        fi
        if [ $option == "3" ]; then
                JAVA=openjdk-6-jre
        fi
        if [ $option == "4" ]; then
                JAVA=openjdk-7-jdk
        fi
        if [ $option == "5" ]; then
                JAVA=openjdk-7-jre
        fi
fi

apt-get -y install $JAVA


############################################################################################
# Installing "LAMP"
# The following command installs the following components:
# openssh-server; apache2; mysql-server; mysql-client; php; phpmyadmin
############################################################################################

apt-get -y install mysql-server phpmyadmin ssh
apt-get -y install dcmtk


############################################################################################


SOURCEDIR=`pwd`

# c:\xampp\php\php.ini de regel Upload_max_filesize = 2M -> Upload_max_filesize = 200M

perl -pi -e 's/^upload_max_filesize = 2M/upload_max_filesize = 200M/g' /etc/php5/apache2/php.ini


# 1. Maak de folder c:\WAD-software aan en kopieer de mappen WAD Interface en WAD Service hier naartoe. WAD Interface bevat de website en de database create-scripts WAD Service bevat de benodigde java applicaties

echo "Restarting apache"
service apache2 restart
echo "Finished restarting apache"

############################################################################################
############################################################################################


echo "Installing DCM4CHEE - MySql"
unzip $ZIP_DCM4CHEE -d $TARGET_DCM4CHEE
#tar -C /opt -xzvf source/dcm4chee-2.17.1-mysql.tgz

# onder x64 krijg je een fout bij het starten van de WADO service
#        (stap 8 van http://www.dcm4che.org/confluence/display/ee2/Installation)
#   werkt: com.sun.imageio.plugins.jpeg.JPEGImageWriter

MACHINE_TYPE=`uname -m`
if [ ${MACHINE_TYPE} == 'x86_64' ]; then
   perl -pi -e 's/value="com.sun.media.imageioimpl.plugins.jpeg.CLibJPEGImageWriter"/value="com.sun.imageio.plugins.jpeg.JPEGImageWriter/g' $TARGET_DCM4CHEE/$(basename $ZIP_DCM4CHEE .zip)/server/default/conf/xmdesc/dcm4chee-wado-xmbean.xml
fi

echo "Finished installing DCM4CHEE - MySQL"

############################################################################################


echo "Creating DCM4CHEE tables"
perl -pi -e "s%^mysql -upacs -ppacs pacsdb.*$/%mysql -upacs -ppacs pacsdb < $TARGET_DCM4CHEE/$(basename $ZIP_DCM4CHEE .zip)/sql/create.mysql\n%g" source/WAD_Interface/create_databases/create_dcm4chee_tables.sh
bash source/WAD_Interface/create_databases/create_dcm4chee_tables.sh $mysqlpwd
echo "Finished creating DCM4CHEE tables"


DCM4CHEE_FOLDER=$TARGET_DCM4CHEE/$(basename $ZIP_DCM4CHEE .zip)
JBOSS_FOLDER=$TARGET_DCM4CHEE/$(unzip -qql $ZIP_JBOSS | head -n1 | awk {'print $4'})

echo "Installing JBOSS"
unzip $ZIP_JBOSS -d $TARGET_DCM4CHEE
bash  $DCM4CHEE_FOLDER/bin/install_jboss.sh $JBOSS_FOLDER
echo "Finished installing JBOSS"


#echo "Installing DCM4CHEE - CDW"
#unzip source/dcm4chee-cdw-2.17.0.zip -d /opt
#bash  /opt/dcm4chee-2.17.3-mysql/bin/install_cdw.sh /opt/dcm4chee-cdw-2.17.0/
#echo "Finished installing DCM4CHEE - CDW"

echo "Installing DCM4CHEE - ARR"
unzip $ZIP_DCM4CHEE_ARR -d $TARGET_DCM4CHEE
bash  $DCM4CHEE_FOLDER/bin/install_arr.sh $TARGET_DCM4CHEE/$(basename $ZIP_DCM4CHEE_ARR .zip)
echo "Finished installing DCM4CHEE - ARR"


#echo "Installing DCM4CHEE - WEB" 
#cp source/dcm4chee-web-3.0.3-mysql.zip   /usr/local/
#unzip /usr/local/dcm4chee-web-3.0.3-mysql.zip -d /usr/local
#bash  /usr/local/dcm4chee-web-3.0.3-mysql/bin/install.sh /usr/local/dcm4chee-2.17.3-mysql/
#echo "Finished installing DCM4CHEE - WEB" 




############################################################################################
# Install WAD Software (Services + Interface)
############################################################################################


echo "Creating IQC tables"
bash source/WAD_Interface/create_databases/create_iqc_tables.sh $mysqlpwd
echo "Finished creating IQC tables"


echo "Installing WAD Interface"

[ -f $TARGET_WAD_INTERFACE/index.html ] && mv $TARGET_WAD_INTERFACE/index.html $TARGET_WAD_INTERFACE/index.old
cp -RL source/WAD_Interface/website/* $TARGET_WAD_INTERFACE
#cp source/wadiqc /etc/apache2/sites-available
#a2ensite wadiqc
#bash /etc/init.d/apache2 restart

chown -R www-data:webadmins $TARGET_WAD_INTERFACE/*
chmod u+x -R $TARGET_WAD_INTERFACE/*


echo "Installing WAD Services"

cp -RL source/WAD_Services/ $TARGET_WAD_SERVICES
mkdir -p $TARGET_XML/analysemodule_output
mkdir -p $TARGET_XML/analysemodule_input

# modify config.xml
perl -pi -e "s%^(\s*<uploads>).*(</uploads>\s*$)%\1$TARGET_WAD_INTERFACE/\2%g" $TARGET_WAD_SERVICES/WAD_Services
perl -pi -e "s%^(\s*<XML>).*(</XML>\s*$)%\1$TARGET_XML/\2%g" $TARGET_WAD_SERVICES/WAD_Services
perl -pi -e "s%^(\s*<archive>).*(</archive>\s*$)%\1$TARGET_DCM4CHEE/$(basename $ZIP_DCM4CHEE .zip)/server/default/\2%g" $TARGET_WAD_SERVICES/WAD_Services


############################################################################################
# Install services
############################################################################################

cp services/WAD-Services $TARGET_STARTSCRIPT/
chmod +x $TARGET_STARTSCRIPT/WAD-Services

read -n 1 -p "Install dcm4chee as a service? [Y/n] " yesno
if [[ "$yesno" == "" || "$yesno" == "y" || "$yesno" == "Y" ]] ; then
	cp services/dcm4chee.conf /etc/init
	perl -pi -e "s%^chdir.*$%chdir $DCM4CHEE_FOLDER/bin%g" /etc/init/dcm4chee.conf
	perl -pi -e "s%^(\s*test -e\s*).*( ||.*$)%\1$DCM4CHEE_FOLDER/bin/run.sh\2%g" /etc/init/dcm4chee.conf
	perl -pi -e "s%^(exec bash\s*).*%\1$DCM4CHEE_FOLDER/bin/run.sh\n%g" /etc/init/dcm4chee.conf
	service dcm4chee start
fi

read -n 1 -p "Install WAD-Services as a service? [Y/n] " yesno
if [[ "$yesno" == "" || "$yesno" == "y" || "$yesno" == "Y" ]] ; then
	cp services/WAD*.conf /etc/init
	perl -pi -e "s%^chdir.*$%chdir $TARGET_WAD_SERVICES/WAD_Services/WAD-Collector/dist%g" /etc/init/WAD-Collector.conf
	perl -pi -e "s%^(\s*test -e\s*).*( ||.*$)%\1$TARGET_WAD_SERVICES/WAD_Services/WAD-Collector/dist/WAD_Collector.jar\2%g" /etc/init/WAD-Collector.conf
	perl -pi -e "s%^chdir.*$%chdir $TARGET_WAD_SERVICES/WAD_Services/WAD-Selector/dist%g" /etc/init/WAD-Selector.conf
	perl -pi -e "s%^(\s*test -e\s*).*( ||.*$)%\1$TARGET_WAD_SERVICES/WAD_Services/WAD-Selector/dist/WAD_Selector.jar\2%g" /etc/init/WAD-Selector.conf
	perl -pi -e "s%^chdir.*$%chdir $TARGET_WAD_SERVICES/WAD_Services/WAD-Processor/dist%g" /etc/init/WAD-Processor.conf
	perl -pi -e "s%^(\s*test -e\s*).*( ||.*$)%\1$TARGET_WAD_SERVICES/WAD_Services/WAD-Processor/dist/WAD_Processor.jar\2%g" /etc/init/WAD-Processor.conf
	service WAD-Collector start
	service WAD-Selector start
	service WAD-Processor start
fi

############################################################################################

echo "Finished installation, enjoy!"

echo
echo "Services can be (re)started or stopped using:"
echo
echo "service <servicename> <command>"
echo
echo "e.g. service WAD-Collector start"
echo
echo "services: WAD-Collector, WAD-Selector, WAD-Processor, dcm4chee"
echo "commands: start, restart, stop, status"
echo
echo "Logfiles can be found under /var/log/upstart/<servicename>.log"
echo
echo "Alternatively, the script "WAD-Services" can be used to (re)start or stop all services at once."
#!/bin/bash

echo "Installing the Cloudstack simulator on local machine. It will take approximately 50 min to setup"
source_dir=/tmp/cloudstack-simulator
destination_dir=/opt
cloudstack_dir=$destination_dir/cloudstack

sudo apt-get update
# Installing required packages
sudo apt-get install \
  ant \
  erlang \
  gcc \
  openjdk-7-jdk \
  python-mysqldb\
  mysql-server \
  python \
  tomcat6 \
  -y
# Rabbitmq for CS
sudo apt-get install rabbitmq-server
# chkconfig alternative for ubuntu
sudo apt-get install sysv-rc-conf

sudo sysv-rc-conf --level 345 rabbitmq-server on
sudo /etc/init.d/rabbitmq-server start

sudo sysv-rc-conf --level 345 mysql on
sudo /etc/init.d/mysql start
#Installing Maven
cd /usr/local
wget http://www.us.apache.org/dist/maven/maven-3/3.0.5/binaries/apache-maven-3.0.5-bin.tar.gz


export M2_HOME=/usr/local/apache-maven-3.0.5
export PATH=${M2_HOME}/bin:${PATH}


curl -L https://github.com/dgrizzanti/cloudstack/archive/4.2-tag-patches.tar.gz | tar -xz
sudo mv cloudstack-4.2-tag-patches $cloudstack_dir
cd $cloudstack_dir
wget https://gist.github.com/justincampbell/8599856/raw/AddingRabbitMQtoCloudStackComponentContext.patch
git apply AddingRabbitMQtoCloudStackComponentContext.patch

#Setting up Cloudstack simulator
sudo mvn -Pdeveloper -Dsimulator -DskipTests -Dmaven.install.skip=true install
#Copying the custom service to start 
sudo cp ./cloudstack-simulator /etc/init.d/cloudstack-simulator

sudo sysv-rc-conf --level 345 cloudstack-simulator on

# CloudStack Configuration
sudo mvn -Pdeveloper -pl developer -Ddeploydb
sudo mvn -Pdeveloper -pl developer -Ddeploydb-simulator
sudo /etc/init.d/cloudstack-simulator start

pip install argparse
while ! nc -vz localhost 8096; do sleep 10; done

#Run tests
sudo mvn -Pdeveloper,marvin.sync -Dendpoint=localhost -pl :cloud-marvin
sudo mvn -Pdeveloper,marvin.setup -Dmarvin.config=setup/dev/advanced.cfg -pl :cloud-marvin integration-test || true

sudo /etc/init.d/cloudstack-simulator stop
#Update data to have similar config with all developers(team)
mysql -uroot cloud -e "update service_offering set ram_size = 32;"
mysql -uroot cloud -e "update vm_template set enable_password = 1 where name like '%CentOS%';"
mysql -uroot cloud -e "insert into hypervisor_capabilities values (100,'100','Simulator','default',50,1,6,NULL,0,1);"
mysql -uroot cloud -e "update user set api_key = 'F0Hrpezpz4D3RBrM6CBWadbhzwQMLESawX-yMzc5BCdmjMon3NtDhrwmJSB1IBl7qOrVIT4H39PTEJoDnN-4vA' where id = 2;"
mysql -uroot cloud -e "update user set secret_key = 'uWpZUVnqQB4MLrS_pjHCRaGQjX62BTk_HU8uiPhEShsY7qGsrKKFBLlkTYpKsg1MzBJ4qWL0yJ7W7beemp-_Ng' where id = 2;"
mysql -uroot cloud -e "update configuration set value = 0 where name like 'max.account.%';"
sudo /etc/init.d/cloudstack-simulator start

echo "Yupiee!! Mission Accomplished"


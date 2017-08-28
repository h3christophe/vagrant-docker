host_ip=`sudo netstat -rn | grep "^0.0.0.0 " | cut -d " " -f10`
sudo sed -i '/vagrant-host #vagrant-host/d' /etc/hosts
sudo echo "$host_ip vagrant-host \#vagrant-host" >> /etc/hosts
sudo echo "$host_ip" > /vagrant/hostip
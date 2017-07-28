# -*- mode: ruby -*-
# vi: set ft=ruby :
require 'yaml'
require 'pathname'

#If your Vagrant version is lower than 1.5, you can still use this provisioning
#by commenting or removing the line below and providing the config.vm.box_url parameter,
#if it's not already defined in this Vagrantfile. Keep in mind that you won't be able
#to use the Vagrant Cloud and other newer Vagrant features.
Vagrant.require_version ">= 1.5"

# Windows / Linux or mac ?
module OS
    def OS.windows?
        (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    end

    def OS.mac?
        (/darwin/ =~ RUBY_PLATFORM) != nil
    end

    def OS.unix?
        !OS.windows?
    end

    def OS.linux?
        OS.unix? and not OS.mac?
    end
end

#is_windows_host = "#{OS.windows?}"
#puts "is_windows_host: #{OS.windows?}"
if OS.windows?
    puts "Vagrant launched from windows."
elsif OS.mac?
    puts "Vagrant launched from mac."
elsif OS.unix?
    puts "Vagrant launched from unix."
elsif OS.linux?
    puts "Vagrant launched from linux."
else
    puts "Vagrant launched from unknown platform."
end


# Auto NetworkDefault Pool
# If you want to change the default pool you will need to manually clear the cache 
# rm ~/.vagrant.d/auto_network/pool.yaml
#AutoNetwork.default_pool = '10.20.1.2/24' 
AutoNetwork.default_pool = '150.100.100.2/24'

Vagrant.configure("2") do |config|
    
    # Check That plugins are installed properly
    [
        { :name => "vagrant-hostmanager", :version => ">= 1.8.6" },
        { :name => "vagrant-auto_network", :version => ">= 1.0.2" }
    ].each do |plugin|

        if not Vagrant.has_plugin?(plugin[:name], plugin[:version])
          raise "#{plugin[:name]} #{plugin[:version]} is required. Please run `vagrant plugin install #{plugin[:name]}`"
        end
    end 


    config.ssh.forward_agent    = true
    
    # SSH KEYS
    config.ssh.insert_key       = false
   
    # sync folders - default
    #config.vm.synced_folder "./provisioners", "/vagrant_provisioners", id: "provisioners", type: "nfs"
    
    # host manager default settings.
    # ==============================
    config.hostmanager.enabled = true
    config.hostmanager.manage_host = true
    config.hostmanager.manage_guest = true
    config.hostmanager.ignore_private_ip = false
    config.hostmanager.include_offline = true

    configuration = YAML::load_file(File.open('configuration.yml'));
    boxName = configuration['machine_name']

    #puts "*TEST (%s)" %[configuration]
      
    allDomains = Array.new
  
    Dir.glob('./sites/*.yml').each do |setting_file|
        settings = YAML::load_file(setting_file);
        #puts "*Settings (%s)" %[settings]
        domains = settings['domains']
        if domains.kind_of?(Array) and !domains.empty?()
            allDomains = allDomains + settings['domains']
        end
    end
    

    #puts "*ALL Domains (%s)" %[allDomains]
    
    ## Define the Virtual Machine
    config.vm.define boxName do |node|

        node.vm.box = configuration['box'] ? configuration['box'] : bento/ubuntu-16.04
        node.vm.network :private_network, :auto_network => true

        # Hostnames
        # ============
        node.vm.hostname = configuration['hostname'] 
        if allDomains.kind_of?(Array) and !allDomains.empty?()
            node.hostmanager.aliases = allDomains
        end

        # SSH KEY
        # ==================
        node.ssh.private_key_path = [ configuration['ssh_private'], "~/.vagrant.d/insecure_private_key"]
        node.vm.provision "file", source: configuration['ssh_public'], destination: "~/.ssh/authorized_keys"

        node.vm.provision "shell", inline: <<-EOC
        sudo sed -i -e "\\#PasswordAuthentication yes# s#PasswordAuthentication yes#PasswordAuthentication no#g" /etc/ssh/sshd_config
        sudo service ssh restart
EOC

        # Host Ip in /etc/hosts/
        node.vm.provision "shell", inline: <<-SCRIPT
        host_ip=`sudo netstat -rn | grep "^0.0.0.0 " | cut -d " " -f10`
        sudo sed -i '/vagrant-host #vagrant-host/d' /etc/hosts
        sudo echo "$host_ip vagrant-host \#vagrant-host" >> /etc/hosts 
SCRIPT

        # Virtual Box
        # ============
        node.vm.provider :virtualbox do |vb|
            vb.customize ["modifyvm", :id, "--memory" , configuration['box_memory'] ? configuration['box_memory'] : "2048"]
            vb.customize ["modifyvm", :id, "--name", boxName]
            vb.customize ["modifyvm", :id, "--cpus", configuration['box_cpus'] ? configuration['box_cpus'] : 2 ]
            vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
            vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
        end

        # Sync Folders
        # ============
        syncFolders = configuration['sync'] ?  configuration['sync'] : false
        if(syncFolders)
            syncFolders.each do |folder_info|
                #print folder_info
                node.vm.synced_folder folder_info['host'], folder_info['guest'], id: folder_info['id'], type: (OS.unix? ? "nfs" : "smb")
            end
        end


        # DOCKER PROVISIONING 
        # ============

        # NGINX proxy
        node.vm.provision "docker" do |d|
            d.pull_images "jwilder/nginx-proxy"

            # sudo docker run -d -p 80:80 -v /var/run/docker.sock:/tmp/docker.sock jwilder/nginx-proxy
            d.run "jwilder/nginx-proxy",
                args: "-p 80:80 -v '/var/run/docker.sock:/tmp/docker.sock'"
        end
        
        # Build and Run Image for each Site
        Dir.glob('./sites/*.yml').each do |setting_file|
            settings = YAML::load_file(setting_file);

            name = settings['build_image_name'] ? settings['build_image_name'] : File.basename(setting_file)
            buildImage = settings['build_image'];
            domains = settings['domains']

            node.vm.provision "docker" do |d|
                d.build_image buildImage,
                    args: "-t "+name
                d.run name,
                    args: "--expose 80 -e VIRTUAL_HOST="+domains.join(',')
            end
           
        end
       

    end
end

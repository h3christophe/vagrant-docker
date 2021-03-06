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
        { :name => "vagrant-auto_network", :version => ">= 1.0.2" },
        { :name => "vagrant-docker-compose", :version => ">= 1.3.0" },
        { :name => "vagrant-triggers", :version => ">= 0.5.3" }
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

    # All Domains.
    allDomains = Array.new 
    Dir.glob('./sites/*.yml').each do |setting_file|
        settings = YAML::load_file(setting_file);
        enabled = settings['enabled']

        if enabled
            services = settings['services'] ? settings['services'] : Array.new;
            for serviceInfo in services
                serviceName = serviceInfo[0];
                settings = serviceInfo[1]
                domains = settings['domains']
                if domains.kind_of?(Array) and !domains.empty?()
                    allDomains = allDomains + settings['domains']
                end
            end
        end
    end

    # Define Box
    config.vm.define boxName do |node|

        node.vm.box = configuration['box'] ? configuration['box'] : bento/ubuntu-16.04
        node.vm.network :private_network, :auto_network => true

        # Hostnames
        # ======================
        node.vm.hostname = configuration['hostname'] 
        if allDomains.kind_of?(Array) and !allDomains.empty?()
            node.hostmanager.aliases = allDomains
        end

        # SSH KEY
        # ======================
        node.ssh.private_key_path = [ configuration['ssh_private'], "~/.vagrant.d/insecure_private_key"]
        node.vm.provision "file", source: configuration['ssh_public'], destination: "~/.ssh/authorized_keys"

        node.vm.provision "shell", inline: <<-EOC
        sudo sed -i -e "\\#PasswordAuthentication yes# s#PasswordAuthentication yes#PasswordAuthentication no#g" /etc/ssh/sshd_config
        sudo service ssh restart
EOC

       

        # Virtual Box
        # ======================
        node.vm.provider :virtualbox do |vb|
            vb.customize ["modifyvm", :id, "--memory" , configuration['box_memory'] ? configuration['box_memory'] : "2048"]
            vb.customize ["modifyvm", :id, "--name", boxName]
            vb.customize ["modifyvm", :id, "--cpus", configuration['box_cpus'] ? configuration['box_cpus'] : 2 ]
            vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
            vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
        end

        # Sync Folders
        # ======================
        syncFolders = configuration['sync'] ?  configuration['sync'] : false
        if(syncFolders)
            syncFolders.each do |folder_info|
                #print folder_info
                node.vm.synced_folder folder_info['host'], folder_info['guest'], id: folder_info['id'], type: (OS.unix? ? "nfs" : "smb")
            end
        end

        # ======================
        # DOCKER PROVISIONING 
        # ======================
        
        # Host Ip in /etc/hosts/
        # ----------------------
        config.vm.provision "trigger", :option => "value" do |trigger|
            trigger.fire do 
            info "============================="
            info "Adding host ip address to the Guest machine"
            info "============================="
            run_remote  "bash /vagrant/vagrant-hostip.sh"
            end
        end

        # Build Docker Compose When Provisioning
        # ----------------------
        config.vm.provision "trigger", :option => "value" do |trigger|
            trigger.fire do
        
            info "============================="
            info "Refreshing DockerCompose File"
            info "============================="
            
            file = File.open("hostip", "r")
            hostip = file.read
            file.close
            
            dockerFilePath = 'docker-compose.yml'

            DockerCompose = {}
            DockerCompose['version'] = "3"

            allNetworks = Array.new;
            services = {};

            # NGINX proxy
            # ----------------------
            proxyService = {}
            proxyService['image'] = "jwilder/nginx-proxy"
            proxyService['container_name'] = "nginx-proxy"
            proxyService['ports'] = ["80:80"]
            proxyService['volumes'] = ["/var/run/docker.sock:/tmp/docker.sock:ro"]
            proxyService['networks'] = ['proxy']
            allNetworks.push('proxy');
            services['nginx-proxy'] = proxyService 

            # Other Sites
            # ----------------------
            Dir.glob('./sites/*.yml').each do |setting_file|
                settings = YAML::load_file(setting_file);
                enabled = settings['enabled']
                if enabled
                    name = settings['name']
                    
                    siteServices = settings['services'] ? settings['services'] : Array.new;
                    for serviceInfo in siteServices
                        serviceName = serviceInfo[0];
                        service = serviceInfo[1]
                        
                        service['container_name'] = serviceName
                        
                        service['networks'] = service['networks'] ? service['networks'] : Array.new
                        if service['networks']
                            service['networks'].push('proxy')
                            allNetworks = allNetworks + service['networks']
                        end 

                        service['environment'] = Array.new
                        if service['domains']
                            service['environment'].push( "VIRTUAL_HOST=" + service['domains'].join(','))
                        end
                        
                        
                        # delete keys not compatible with docker-compose
                        service.delete('domains');

                        # Vagrant Hostname.
                        service['extra_hosts'] = Array.new
                        service['extra_hosts'].push("vagrant-host:"+hostip.strip);
                        
                        services[serviceName] = service
                    end               
                end 
            end

            DockerCompose['services'] = services

            DockerCompose['networks'] = {}
            for network in allNetworks.uniq()
                DockerCompose['networks'][network] = {}
            end

            # Write to File
            File.open(dockerFilePath, 'w') {|f| f.write DockerCompose.to_yaml }
            end
        end

        # Build Other Containers
        # ----------------------
        
        if false
            node.vm.provision :docker do |d|
                # Build all Necessary Images from path
                Dir.glob('./sites/*.yml').each do |setting_file|
                    settings = YAML::load_file(setting_file);
                    enabled = settings['enabled']
                    if enabled
                        imageName = settings['name'] ? settings['name'] : File.basename(setting_file)
                        buildImage = settings['build_image'];

                        # BUILD Images.
                        d.build_image buildImage, args: "-t "+imageName
                    end  
                end
            end
        end
        
        # Docker Compose.
        # ----------------------
        node.vm.provision :docker_compose do |compose|
            compose.yml = "/vagrant/docker-compose.yml"
            compose.rebuild = true
            compose.command_options = {rm: "", up: "-d --remove-orphans"}   
        end

        # Docker Cleanup.
        # ----------------------
        node.trigger.after :provision do
            run_remote  "bash /vagrant/cleanup.sh"
        end
    end

end
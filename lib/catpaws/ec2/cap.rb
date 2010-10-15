require 'catpaws/base/cap'
require 'catpaws/ec2/catpaws'

#This isn't really what Cap was designed for. Tasks shouldn't really be running
#stuff on localhost and it'll all break if you can't ssh to localhost. 
#It's just a temporary kludge. The plan is to write a new  DSL that takes a bit from
#Rake and a bit from Cap and is designed for running data analysis type workflows.


Capistrano::Configuration.instance(:must_exist).load do

  #asw_access_key and aws_secret_access_key are set in base.

  # default to EU West
  set_default (:ec2_url)  {'eu-west-1.ec2.amazonaws.com'}
 
  # check we have one and only one master node 
  master = find_servers(:role => 'master')
  unless(master) 
    raise CaTPAWS::EC2::Error::NoMaster, 'No server assigned to master role'
  end
  
  if master.length > 1 
    raise CaTPAWS::EC2::Error::MultipleMaster, 'Multiple servers assigned to master role'
  end
 
  #for reasons I don't understand, you can't set a cap role in a namespace, but you can call a function
  #that isn't in a namespace from a task in a namespace. Which seems wierd. But apparently works. 
  def set_role(params)
 
    role_name   =  params[:role_name] or raise CaTPAWS::EC2::Error::MissingParameter, 'Trying to set a role without a role_name'
    server_list =  params[:server_list] or raise  CaTPAWS::EC2::Error::MissingParameter, 'Trying to set a role without a server_list'
    attributes  =  params[:attributes] || {}
    block       =  params[:block] || nil
    
    if block_given?
      role(role_name, server_list, attributes, block)
    else
      role(role_name, server_list, attributes)
    end

  end
    

  namespace :EC2 do 
    
    desc 'Start a group of EC2 images'
    task :start, :roles => :master do

      #Define these in the config. Or as command line params with -S, but config is easier.
      group_name        = variables[:group_name] or abort "No group_name set in config or task parameters"
      cat_group_name    = "CaTPAWS_#{group_name}"
      group_description = variables[:group_description] || "A group created by CaTPAWS (http://github.com/cassj/catpaws)"
      nhosts            = variables[:nhosts] || 1
      ami               = variables[:ami] or abort "No ami specified in config or task parameters' "
      instance_type     = variables[:instance_type] or abort "No instance type specified in config or task parameters'"
      key               = variables[:key] or abort "No key (for ssh) specified in config or task parameters' "
      key_file          = variables[:key_file] || ''
      ssh_to_port       = variables[:ssh_to_port] || 22
      ssh_from_port     = variables[:ssh_from_port] || 22
      ssh_cidr_ip       = variables[:ssh_cidr_ip] || '0.0.0.0/0'
      ec2_url           = variables[:ec2_url] or abort "no ec2_url defined"
      working_dir       = variables[:working_dir]
      catpaws_logfile    = variables[:catpaws_logfile] 

      #create a CaTPAWS::EC2::Instances object for the group we want.
      #if the group already exists, it'll check 
      instances = CaTPAWS::EC2::Instances.new(
                                              :group_name        => cat_group_name,
                                              :group_description => group_description,
                                              :ami               => ami,
                                              :instance_type     => instance_type,
                                              :key               => key,
                                              :key_file          => key_file,
                                              :nhosts            => nhosts,
                                              :access_key        => aws_access_key,
                                              :secret_access_key => aws_secret_access_key,
                                              :ec2_url           => ec2_url,
                                              :working_dir       => working_dir,
                                              :catpaws_logfile   => catpaws_logfile

                                              )
      

      #can we add the location of the key_file to the ssh settings? 
      #for now, just use ssh_add.
      instances.dns_name.each{|server| set_role({
                                                  :role_name => group_name.intern, 
                                                  :server_list => server
                                                }) }
      

      set :instances, instances

    end
    after 'EC2:start', 'EC2:setup'


    #Define a task to setup the instances.
    task :setup, :roles => proc{fetch :group_name} do
      instances = fetch :instances

      #just wait a sec for the server to do boot stuff. Seems to fail sometimes if not.
      sleep(5)
      
      user = variables[:ssh_options][:user]
      working_dir = instances.working_dir
      unless (working_dir == ".")
        sudo "mkdir -p #{working_dir}"
        sudo "chown -R #{user} #{working_dir}"
      end

    end


    desc 'Stop the group of EC2 images - note that this depends on EC2:start'
    task :stop, :roles => :master do
      #Define these in the config. Or as command line params with -S, but config is easier.
      group_name        = variables[:group_name] or abort "No group_name set in config or task parameters"
      cat_group_name    = "CaTPAWS_#{group_name}"
      ec2_url           = variables[:ec2_url] or abort "no ec2_url defined"
      catpaws_logfile   = variables[:catpaws_logfile]

      #create a CaTPAWS::EC2::Instances object for the group we want.
      #use no_new so we don't start new stuff if nothing is running
      begin
        instances = CaTPAWS::EC2::Instances.new(
                                                :group_name        => cat_group_name,
                                                :access_key        => aws_access_key,
                                                :secret_access_key => aws_secret_access_key,
                                                :ec2_url           => ec2_url,
                                                :no_new            => true,
                                                :catpaws_logfile   => catpaws_logfile
                                                )
      
        
        #shutdown the instances
        instances.shutdown
        
        #remove the role associated with this instance group
        #note that according to the docs this is read only, so we probably shouldn't
        #be doing this.
        roles.delete(group_name.intern)
        
        puts "instances shutdown"

      rescue
        #task should be idempotent. If group isn't found, it's probably because the task has already run once
        #only panic if we still have the correponding cap role
        #if roles.has_key('group_name')
          raise $!
        #end
      end
      
    end #stop
    

  end #namespace EC2

  
  #don't need any catpaws code for ebs, tasks just use 
  #the rightaws gem
  namespace :EBS do 
    
    desc 'Create a new EBS volume'
    task :create, :roles => :master do
      
      #so, we'll tag ebs volumes for this project and then we can delete them as a group
      ec2_url   = variables[:ec2_url] || ec2_url or abort "no ec2_url defined"
      ec2_url = "#{ec2_url}/" unless ec2_url[-1,1] == '/' #add a trailing slash if it doesn't have one.
     
      ebs_tag   = variables[:ebs_tag] || variables[:group_name] or abort 'ebs_tag or group_name must be set to create ebs volumes'
      ebs_size  = variables[:ebs_size] || 10
      ebs_size  = ebs_size.to_i
      zone      = variables[:ebs_zone] or  abort 'No ebs_zone set for volume creation'
      catpaws_logfile    = variables[:catpaws_logfile] 
      

      #get connection
      #:logger       => catpaws_logfile
      ec2 = RightAws::Ec2.new(aws_access_key, aws_secret_access_key,
                              { :endpoint_url => ec2_url
                              })
      
      vol= ec2.create_volume(nil, ebs_size, zone)
      #but we could just make the call ourselves like:
#      call = "https://ec2.amazonaws.com/?Action=CreateTags"
#      "&ResourceId.2=i-7f4d3a2b"
#      "&Tag.1.Key=webserver"
#      "&Tag.1.Value="
#      "&Tag.2.Key=stack"
#      "&Tag.2.Value=Production"
#      "&AuthParams"
    end
    
    desc 'Create a new EBS volume from existing snapshot'
    task :create_from_snap, :roles => :master do
      puts "I would create a volume from a snapshot"
    end

    desc 'Delete EBS volume'
    task :delete, :roles => :master do
      puts "I would delete a volume"
      
      ec2 = RightAws::Ec2.new(@access_key, @secret_access_key,
                                { :endpoint_url => @ec2_url,
                                  :logger       => @catpaws_log
                                })
      
      ec2.delete_volume('vol-b48a6fdd')
      
    end

  end #namespace EBS
  

end #config.load




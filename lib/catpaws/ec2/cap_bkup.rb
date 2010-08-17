require '/space/cassj/catpaws/lib/catpaws/base/cap'
require '/space/cassj/catpaws/lib/catpaws/ec2/catpaws'


Capistrano::Configuration.instance(:must_exist).load do

  # default to EU West.
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
                                              :secret_access_key => aws_secret_access_key
                                              )
      

      #can we add the location of the key_file to the ssh settings? 
      #for now, just use ssh_add.
      instances.dns_name.each{|server| set_role({
                                                  :role_name => group_name.intern, 
                                                  :server_list => server
                                                }) }
      

      set :instances, instances

    end
    after 'EC2:start', 'EC2:status_setup'


    #why is this failing just sometimes?
    task :status_setup, :roles => proc{fetch :group_name} do
      instances = fetch :instances

      #just wait a sec for the server to do boot stuff. Seems to fail sometimes if not.
      sleep(5)
 
      #create the status file on each of the instances unless it already exists.
      #this is basically just a json file in which you can dump whatever metadata 
      #you like for your task. catpaws will use it for keeping track of running jobs,
      #but you can add your own stuff too. Top level structure must be a hash, but 
      #below that, whatever data structure you like.
      #it should be empty if there is no task running on this instance.
      status_file = instances.status_file
      run "touch #{status_file}"
      
    end


    desc 'Stop the group of EC2 images - note that this depends on EC2:start'
    task :stop, :roles => :master do
      #parse stuff
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
      
      
      #create a CaTPAWS::EC2::Instances object for the group we want.
      #use no_new so we don't start new stuff if nothing is running
      begin
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
                                                :no_new            => true
                                                )
        
        #shutdown the instances
        instances.shutdown
        
        #remove the role associated with this instance group
        #note that according to the docs this is read only, so we probably shouldn't
        #be doing this.
        roles.delete(@group_name)
        
        puts "instances shutdown"
        
      rescue AWS::InvalidGroupNotFound
        #task should be idempotent. If group isn't found, it's probably because the task has already run once
        #only panic if we still have the correponding cap role
        if roles.has_key('group_name')
          raise $!
        end
      end
      
    end #stop

#    desc 'update instance statuses'
#    task :poll_instances, roles => :master do
#      instances = fetch :instances
#      puts instances
#      status_file = instances.status_file
#      
#      status = JSON.parse(capture("cat #{status_file}"))
#
#    end
#    before 'EC2:poll_instances', 'EC2:start'

  end #namespace EC2

end #config.load




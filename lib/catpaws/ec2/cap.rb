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
        if roles.has_key('group_name')
          raise $!
        end
      end
      
    end #stop
    

  end #namespace EC2

  
  #why not just use the ec2 gem to create ebs volumes? 
  #this way we can fit it into a workflow I suppose,
  #need to figure out what to do about attachment to multiple instances too.
  namespace :EBS do 
    
    desc 'Create a new EBS volume'
    task :create, :roles => :master do
      
      ec2_url   = variables[:ec2_url] || ec2_url or abort "no ec2_url defined"
      ec2_url   = "#{ec2_url}/" unless ec2_url[-1,1] == '/' #add a trailing slash if it doesn't have one.
      snap_id   = variables[:snap_id] || nil 
      ebs_tag   = variables[:ebs_tag] || variables[:group_name] or abort 'ebs_tag or group_name must be set to create ebs volumes'
      ebs_size  = variables[:ebs_size] || 10
      ebs_size  = ebs_size.to_i
      zone      = variables[:ebs_zone] or  abort 'No ebs_zone set for volume creation'
      catpaws_logfile    = variables[:catpaws_logfile] 
      

      #get connection
      ec2 = RightAws::Ec2.new(aws_access_key, aws_secret_access_key,
                              { :endpoint_url => ec2_url,
                                :logger       => catpaws_logfile
                              })
      
      vol= ec2.create_volume(snap_id, ebs_size, zone)
      `echo #{vol[:aws_id]} > VOLUMEID`
      #this doesn't yet work on Eucalyptus. Or at least, not on the 
      #version that the Oxford cloud has installed. Fine on EC2 though.
      #ec2.create_tags('CaTPAWS_tag', ebs_tag, vol[:aws_id])
    end
    

    #how to delete all volumes created for these instances?
    #presumably if they just wanted to delete an ind
    desc 'Delete EBS volume'
    task :delete, :roles => :master do
      ec2_url   = variables[:ec2_url] || ec2_url or abort "no ec2_url defined"
      ec2_url   = "#{ec2_url}/" unless ec2_url[-1,1] == '/' #add a trailing slash if it doesn't have one.
      catpaws_logfile    = variables[:catpaws_logfile]


      #get connection
      ec2 = RightAws::Ec2.new(aws_access_key, aws_secret_access_key,
                              { :endpoint_url => ec2_url,
                                :logger       => catpaws_logfile
                              })
      
      ec2.delete_volume(vol_id)
      `echo "" >  VOLUMEID`      
    end

    desc 'Delete all volumes with a given tag'
    task :delete_by_tag, :roles=> :master do
       puts "TODO"
    end 

 
    desc "attach vol_id to instance"
    task :attach, :roles => :master do
      group_name        = variables[:group_name] or abort "No group_name set in config or task parameters"
      cat_group_name    = "CaTPAWS_#{group_name}"
      ec2_url           = variables[:ec2_url] or abort "no ec2_url defined"
      catpaws_logfile   = variables[:catpaws_logfile]
      vol_id            = variables[:vol_id] or abort "no vol_id defined"
      dev               = variables[:dev] or abort "no dev defined"

	
      #create a CaTPAWS::EC2::Instances object for the group we want.
      #use no_new so we don't start new stuff if nothing is running
      instances = CaTPAWS::EC2::Instances.new(
                                              :group_name        => cat_group_name,
                                              :access_key        => aws_access_key,
                                              :secret_access_key => aws_secret_access_key,
                                              :ec2_url           => ec2_url,
                                              :no_new            => true,
                                              :catpaws_logfile   => catpaws_logfile
                                              )

      if (instances.id.length>1) 
        abort "TODO - can't attach to multiple instances yet."
      end

      id = instances.id[0]
      ec2 = instances.ec2
      
      ec2.attach_volume(vol_id, id, dev)

    end

    desc "format a new EBS - unneccessary if you've created it from snapshot"
    task :format_xfs, :roles => proc{fetch :group_name} do
       dev = variables[:dev] or abort "no dev defined"
       run "sudo apt-get install -y xfsprogs"
       #run "sudo modprobe xfs" #should be built into the kernel apparently
       run "sudo mkfs.xfs #{dev}"
    end 
    before 'EBS:format_xfs', 'EC2:start'    



    desc "mount an XFS filesystem"
    task :mount_xfs, :roles => proc{fetch :group_name} do
       dev = variables[:dev] or abort "no dev defined"
       mount_point = variables[:mount_point] or abort "no mount_point defined"
       user = variables[:ssh_options][:user]

       #make an fstab entry if we don't already have one.
       fstab = capture("cat /etc/fstab")
	if (fstab.match(/#{dev}/) || fstab.match(/#{mount_point}/))
          unless fstab.match(/#{dev}\s+#{mount_point}/)
            abort "Conflicting entry in fstab, please check manually"
          end
       else
          run "echo '#{dev} #{mount_point} xfs noatime 0 0' | sudo tee -a /etc/fstab"
          run "sudo mkdir #{mount_point}"
       end
      
       #check mtab to see if we're already mounted
       mtab = capture("cat /etc/mtab")
       if (mtab.match(/#{dev}/) || mtab.match(/#{mount_point}/))
          unless mtab.match(/#{dev}\s+#{mount_point}/)
            abort "Conflicting entry in mtab, please check manually"
          end
       else
   	 #mount your fs
         run "sudo mount #{mount_point}"
         #grow your filesystem if you can 
         run "sudo apt-get update &&  sudo apt-get install -y xfsprogs"
         run "sudo xfs_growfs #{dev}"
         #and give user ownership of all files
         run "sudo chown -R #{user}:#{user} #{mount_point}"
       end 

    end
    before "EBS:mount_xfs", 'EC2:start'
   
    desc "unmount a filesystem"
    task :unmount, :roles => proc{fetch :group_name} do
       run "sudo umount #{mount_point}"
    end
    before "EBS:unmount", "EC2:start"
 
    desc "snapshot a mounted EBS volume"
    task :snapshot, :roles => :master do
      group_name        = variables[:group_name] or abort "No group_name set in config or task parameters"
      cat_group_name    = "CaTPAWS_#{group_name}"
      ec2_url           = variables[:ec2_url] or abort "no ec2_url defined"
      catpaws_logfile   = variables[:catpaws_logfile]
      vol_id            = variables[:vol_id] or abort "no vol_id defined"

      instances = CaTPAWS::EC2::Instances.new(
                                              :group_name        => cat_group_name,
                                              :access_key        => aws_access_key,
                                              :secret_access_key => aws_secret_access_key,
                                              :ec2_url           => ec2_url,
                                              :no_new            => true,
                                              :catpaws_logfile   => catpaws_logfile
                                              )


      #probably this should snapshot all vols associated with this instance group?
      if (instances.id.length>1)
        abort "TODO - can't snapshot from instances yet."
      end
	
      #but for now just use a pre-specified vol_id
      ec2 = instances.ec2
      snap = ec2.create_snapshot(vol_id) 
      `echo #{snap[:aws_id]} > SNAPID`
	#TODO - need to wait while this is pending
    end
    


    desc "detach vol_id from instance"
    task :detach, :roles => :master do

      group_name        = variables[:group_name] or abort "No group_name set in config or task parameters"
      cat_group_name    = "CaTPAWS_#{group_name}"
      ec2_url           = variables[:ec2_url] or abort "no ec2_url defined"
      catpaws_logfile   = variables[:catpaws_logfile]
      vol_id            = variables[:vol_id] or abort "no vol_id defined"
      mount_point       = variables[:mount_point] or abort "no mount point defined"

      #create a CaTPAWS::EC2::Instances object for the group we want.
      #use no_new so we don't start new stuff if nothing is running
      instances = CaTPAWS::EC2::Instances.new(
                                              :group_name        => cat_group_name,
                                              :access_key        => aws_access_key,
                                              :secret_access_key => aws_secret_access_key,
                                              :ec2_url           => ec2_url,
                                              :no_new            => true,
                                              :catpaws_logfile   => catpaws_logfile
                                              )
      if (instances.id.length>1)
        abort "TODO - can't attach to multiple instances yet."
      end

      ec2 = instances.ec2
      ec2.detach_volume(vol_id)

    end



  end #namespace EBS
  

end #config.load




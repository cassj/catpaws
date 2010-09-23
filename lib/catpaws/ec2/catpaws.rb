require 'catpaws/base/catpaws'

####
#
# CaTPAWS EC2
# 
# Module to facilitate managing ec2 instances by group for running Capistrano tasks. 
# Essentially just a wrapper around the amazon-ec2 gem functionality that parses the 
# ec2 responses and organises everything by security group for running cap tasks.
# Not intended to be used outside the CaTPAWS / Capistrano context.

module CaTPAWS
  module EC2

    #errors
    module Error
      MissingParameter      = Class.new(CaTPAWS::Error::AWSError)
      InstanceRetrieval     = Class.new(CaTPAWS::Error::AWSError)
      InstanceStartup       = Class.new(CaTPAWS::Error::AWSError)
      InstanceShutdown      = Class.new(CaTPAWS::Error::AWSError)
      GroupPermissions      = Class.new(CaTPAWS::Error::AWSError)
      NoMaster              = Class.new(CaTPAWS::Error::AWSError)
      MultipleMaster        = Class.new(CaTPAWS::Error::AWSError)
    end #Error
    
    # Class to store the EC2 instances for a given group. 
    # will create new instances if required or retrieve existing ones and do some basic sanity checks on them
    class Instances

      def initialize(params)
        

        #process the params. Note that even if we're just retrieving an existing group, you need to specify all the 
        #params because we need to check that the instances in that group are what they should be for the cap task.
        @access_key        = params[:access_key] or raise CaTPAWS::EC2::Error::MissingParameter, 'Please provide an AWS access_key'
        @secret_access_key = params[:secret_access_key] or raise CaTPAWS::EC2::Error::MissingParameter, 'Please provide an AWS secret_access_key'
        @ec2_url           = params[:ec2_url] || 'eu-west-1.ec2.amazonaws.com'
        @group_name        = params[:group_name] or raise CaTPAWS::EC2::Error::MissingParameter, 'Please provide a group_name'
        @group_description = params[:group_description] || ''
        @nhosts            = params[:nhosts] || 1
        @ami               = params[:ami] or raise CaTPAWS::EC2::Error::MissingParameter, 'Please provide an ami   '
        @instance_type     = params[:instance_type] or raise CaTPAWS::EC2::Error::MissingParameter, 'Please provide an instance_type'
        @key               = params[:key] or raise  CaTPAWS::EC2::Error::MissingParameter, 'Please specify a key to use in order to gain ssh access to instances'
        @ssh_to_port       = params[:ssh_to_port] || 22
        @ssh_from_port     = params[:ssh_from_port] || 22
        @ssh_cidr_ip       = params[:ssh_cidr_ip] || '0.0.0.0/0'
        @status_file       = params[:status_file] or raise  CaTPAWS::EC2::Error::MissingParameter, 'Please specify a status_file location for instances in this group'
        @working_dir       = params[:working_dir] or raise CaTPAWS::EC2::Error::MissingParameter, 'Please specify a working_dir'
        @no_new            = params[:no_new] || false

        puts @ec2_url

        # create ec2 connection for this object
        @ec2 = AWS::EC2::Base.new( :access_key_id     => @access_key,
                                   :secret_access_key => @secret_access_key,
                                   :server            => @ec2_url
                                   ) 
        

        # try creating a new group and nhosts within it
        begin
          
          if (@no_new)
            sec_group = @ec2.describe_security_groups(:group_name => @group_name)
          else
            @ec2.create_security_group(:group_name        => @group_name,
                                       :group_description => @group_description)
            
            
            set_group_perms(:ip_protocol => 'tcp',
                            :from_port   => @ssh_from_port, 
                            :to_port     => @ssh_to_port,
                            :cidr_ip     => @ssh_cidr_ip
                            )
        
            #start required instances.
            @ec2.run_instances(
                               :image_id       => @ami, 
                               :security_group => @group_name,
                               :min_count      => @nhosts, 
                               :max_count      => @nhosts, 
                               :key_name       => @key,
                               :instance_type  => @instance_type
                               )
            
            
            #NOTE TO SELF:
            # according to the amazon-ec2 docs, the key data is put in /dev/sda2/openssh_id.pub
            # and can be copied to ~/.ssh/authorized_keys for ssh access
            # I'm not copying it and it still works, but maybe the ubuntu images just do this for you
            # at boot, so if it doesn't work with other images, maybe this is the reason? Don't need 
            # other images at the moment so am not bothering to test it.
            
            
            #we need to setup instance attributes at this point. At least available=>true
            #what's the best way of doing this? Later, I guess we're going to need info about the 
            #running task, where it's output is going so we can tail it from cap, maybe a status
            #flag that can be RUNNING, STOPPED, COMPLETED etc. Maybe we don't want to start another 
            #job until the results of the last one have been successfully collated. And probably we want 
            #to define cap tasks to monitor running jobs, check for fuckups, email you if there's
            # a problem and so forth. This is inevitably going to involve installing something on the
            # instances. hmm.
          end
          
        rescue AWS::InvalidGroupDuplicate 
          #has ssh perms?
          unless check_group_perms(:ip_protocol => 'tcp',
                                   :from_port   => @ssh_from_port, 
                                   :to_port     => @ssh_to_port,
                                   :cidr_ip     => @ssh_cidr_ip
                                   )
            raise  CaTPAWS::EC2::Error::GroupPermissions, "Permissions not set for ssh from port #{@ssh_from_port} to port #{@ssh_to_port} for IP range #{@ssh_cidr_ip}"
          end
          #get and check instances
        rescue 
          raise $! #rethrow
        end

        # load the metadata about the instances in this group
        get_instances()
        
        # wait for any pending for a couple of minutes
        attempts = 0
        stats = state_code()
        while (stats.any? {|s| s==0 }) do
          if attempts > 6 
            raise CaTPAWS::EC2::Error::InstanceStartup, "Instances still pending after a long wait. Check your EC2 account manually?"
          end
          puts "Pending instances, please wait..."
          sleep(10)
          attempts+=1
          get_instances()
          stats = state_code()
        end
        
        unless (@instances.length == @nhosts)
           raise CaTPAWS::EC2::Error::InstanceRetrieval, "Number of running instances in this group does not match nhosts"
        end

        unless  ami().all?{|a| a == @ami } 
          raise CaTPAWS::EC2::Error::InstanceRetrieval, "Running instances in this group are not all instances of ami #{@ami}"
        end
        
        unless key_name().all?{|k| k == @key}
          raise CaTPAWS::EC2::Error::InstanceRetrieval, "Running instances in this group do not have key #{@key}"
        end


        #initialise the status array
        @status = []

      end #initalize
    
      
      #shutdown all the instances in this group
      def shutdown()

        #shutdown all the instances we have.
        ids = id()

        @ec2.terminate_instances(:instance_id => ids)
        
        # wait for them to shut down for a couple of minutes
        attempts = 0
        stats = state_code()
        while (stats.any? {|s| s<=16 }) do
          if attempts > 6 
            raise CaTPAWS::EC2::Error::InstanceShutdown, "Instances still running after a long wait. Check your EC2 account manually?"
          end
          puts "Terminating instances, please wait..."
          sleep(10)
          attempts+=1
          get_instances(true)
          stats = state_code()
        end

        #and delete the associated security group
        @ec2.delete_security_group(:group_name => @group_name)

      end



      def set_group_perms(params)
        @ec2.authorize_security_group_ingress(:group_name  => @group_name,
                                              :ip_protocol => params[:ip_protocol],
                                              :from_port   => params[:from_port],
                                              :to_port     => params[:to_port],
                                              :cidr_ip     => params[:cidr_ip]
                                              )
        
      end
      public :set_group_perms


      def check_group_perms(params)
        
        ip_protocol = params[:ip_protocol] or raise  CaTPAWS::EC2::Error::MissingParameter, 'ip_protocol'
        port       = params[:port]
        from_port   = params[:from_port] || port or raise CaTPAWS::EC2::Error::MissingParameter, 'from_port'
        to_port     = params[:to_port] || port or raise CaTPAWS::EC2::Error::MissingParameter, 'to_port'
        cidr_ip    = params[:cidr_ip] || '0.0.0.0/0'
        
        sec_group = @ec2.describe_security_groups(:group_name => @group_name)
        
        #puts sec_group.securityGroupInfo

        sec_exists = false
        sec_group.securityGroupInfo.item[0].ipPermissions.item.each do |perm|
          if ( ( perm.ipProtocol==ip_protocol ) && 
               ( perm.fromPort==from_port.to_s ) && 
               ( perm.toPort == to_port.to_s ) &&
               ( perm.ipRanges.item[0].cidrIp == cidr_ip )
               )
            sec_exists = true
          end
        end 

        return sec_exists

      end
      public :check_group_perms

      
      #retrieve and parse the instances for this group
      def get_instances(incl_stopped=false)
        rs = @ec2.describe_instances.reservationSet.item
        
        #determine which rs contains a group with the group name
        has_group = []
        rs.each_with_index {|r, r_ind|    
          if(r.groupSet.item.map{|g| g.groupId}.include?(@group_name))
            has_group.push(r_ind)
          end
        }
        
        if(has_group.length==0)
          raise CaTPAWS::EC2::Error::InstanceRetrieval, "No instances found in this group"
        end 
        
        #make an array of the instances in this group from all reservation sets 
        @instances = Array.new()
        has_group.each {|indx| @instances.concat(rs[indx].instancesSet.item) }        

        if @instances.length == 0
          raise CaTPAWSErr::EC2::InstanceError, "No instances found in this group"
        end
        
        #get the status codes for each instance
        stats = state_code()
          
        #and chuck out any that are no longer running
        unless (incl_stopped)
          running = Array.new()
          stats.each_index{|i| 
            if (stats[i] <= 16) 
              running.push i
            end
          }
          @instances  = running.map {|i| @instances[i]}
        end
       end
      private :get_instances


      #returns the location of the status file on instances in this group
      def status_file()
        return @status_file
      end
      public :status_file
      
      def working_dir()
         return @working_dir
      end
      public :working_dir



      #returns the array of instance metadata
      def instances()
        return @instances
      end
      public :instances

      
      #can we auto-generate these methods?
      #need a get, a set for the whole array
      #a set for indices


      #get currently cached instance statuses
      def status()
        return @status
      end
      public :status
      
      #set statuses
      def set_status(stat)
        @status = stat
      end

      
      


      #getters for all the standard ec2-describe-instances info
      #all return an array of the relevant metadata ordered as per @instances
      def id( )
      
        return @instances.map{ |i| i.instanceId }
        
      end
      public :id

      def state()
        
        stats  = Hash[]        
        @instances.each{ |i| stats[i.instanceId]  = i.instanceState  }
        return stats
        
      end
      public :state
        
      def state_code()
        return state().values.map{|i| i.code.to_i }
      end
      public :state_code
      
      def state_name()
        return state().values.map{|i| i.name}
      end
      public :state_name

      def ami( )
        return @instances.map{ |i| i.imageId }
      end
      public :ami  
      
      def dns_name()
        return @instances.map{|i| i.dnsName }
      end
      public :dns_name

      def private_dns_name()
        return @instances.map{|i| i.privateDnsName}
      end
      public :private_dns_name
      
      def key_name()
        return @instances.map{|i| i.keyName}
      end
      public :key_name

      def type()
        return @instances.map{|i| i.instanceType}
      end
      public :type

      def launch_time()
        return @instances.map{|i| i.launchTime}
      end
      public :launch_time

      def availability_zone()
        return @instances.map{|i| i.placement.availabilityZone}
      end
      public :availability_zone
      
      def ami_launch_index()
        return @instances.map{|i| i.amiLaunchIndex}
      end
      public :ami_launch_index

      def ip_address()
        return @instances.map{|i| i.ipAddress }
      end
      public :ip_address
      
      def private_ip_address()
        return @instances.map{|i| i.privateIpAddress}
      end
      public :private_ip_address
      
      def architecture()
        return @instances.map{|i| i.architecture}
      end
      public :architecture

      def root_device_type()
        return @instances.map{|i| i.rootDeviceType}
      end
      public :root_device_type

      def monitoring()
        return @instances.map{|i| i.monitoring}
      end
      public :monitoring

      def monitoring_state()
        return @instances.map{|i| i.monitoring.state}
      end
      public :monitoring_state

      def block_device_mapping()
        return @instances.map{|i| i.blockDeviceMapping}
      end

    end #Instances class
    
  end #EC2
end #CaTPAWS













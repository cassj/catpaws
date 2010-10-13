# -*- coding: utf-8 -*-
require 'catpaws/base/catpaws'

####
#
# CaTPAWS EC2
# 
# Module to facilitate managing ec2 instances by group for running Capistrano tasks. 
# Essentially just a wrapper around the right_aws gem that parses the 
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
        
        #sometimes we want to be explicit about not creating new instances (eg EC2:stop shouldn't try and start instances to stop them)
        @no_new            = params[:no_new] || false
        
        #these we need regardless
        @access_key        = params[:access_key] or raise CaTPAWS::EC2::Error::MissingParameter, 'Please provide an AWS access_key'
        @secret_access_key = params[:secret_access_key] or raise CaTPAWS::EC2::Error::MissingParameter, 'Please provide an AWS secret_access_key'
        @ec2_url           = params[:ec2_url] || 'eu-west-1.ec2.amazonaws.com'
        @group_name        = params[:group_name] or raise CaTPAWS::EC2::Error::MissingParameter, 'Please provide a group_name'
 
        unless (@no_new)
          @group_description = params[:group_description] || ''
          @nhosts            = params[:nhosts] || 1
          @ssh_to_port       = params[:ssh_to_port] || 22
          @ssh_from_port     = params[:ssh_from_port] || 22
          @ssh_cidr_ip       = params[:ssh_cidr_ip] || '0.0.0.0/0'
          @working_dir       = params[:working_dir] || '.'
          @ami               = params[:ami] or raise CaTPAWS::EC2::Error::MissingParameter, 'Please provide an ami   '
          @instance_type     = params[:instance_type] or raise CaTPAWS::EC2::Error::MissingParameter, 'Please provide an instance_type'
          @key               = params[:key] or raise  CaTPAWS::EC2::Error::MissingParameter, 'Please specify a key to use in order to gain ssh access to instances'
        end
        
        #get connection
        @ec2   = RightAws::Ec2.new(@access_key, @secret_access_key,
                                   { :endpoint_url => @ec2_url }  
                                   )

        unless(@no_new)
          # try creating a new group and nhosts within it
          begin
            @ec2.create_security_group(@group_name, @group_description)

            set_group_perms(:ip_protocol => 'tcp',
                            :from_port   => @ssh_from_port, 
                            :to_port     => @ssh_to_port,
                            :cidr_ip     => @ssh_cidr_ip
                            )
            
            
            @ec2.run_instances(@ami, 
                               @nhosts,
                               @nhosts, 
                               [@group_name], 
                               @key, 
                               '',
                               nil, 
                               @instance_type
                               )
            
          rescue RightAws::AwsError => e
            
            first_error =  e.errors.shift
            error_code = first_error[0]
            
            #if the group exists, do some basic sanity checks and just use the instances in it
            if (error_code == "InvalidGroup.Duplicate")
              #has ssh perms?
              unless check_group_perms(:ip_protocol => 'tcp',
                                       :from_port   => @ssh_from_port, 
                                       :to_port     => @ssh_to_port,
                                       :cidr_ip     => @ssh_cidr_ip
                                       )
                raise  CaTPAWS::EC2::Erreor::GroupPermissions, "Permissions not set for ssh from port #{@ssh_from_port} to port #{@ssh_to_port} for IP range #{@ssh_cidr_ip}"
              end
            end
            
          rescue 
            raise $! #rethrow
          end #begin
          
        end #unless 

        # load the metadata about the instances in this group
        get_instances()

        unless (@no_new)
          # wait for any pending for up to 5 mins
          attempts = 0
          stats = state_code()
          while (stats.any? {|s| s==0 }) do
            if attempts >  10
              raise CaTPAWS::EC2::Error::InstanceStartup, "Instances still pending after a long wait. Check your EC2 account manually?"
            end
            puts "Pending instances, please wait..."
            sleep(30)
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
        end
        
      end #initalize
    
      
      #shutdown all the instances in this group
      def shutdown()

        #shutdown all the instances we have.
        ids = id()

        @ec2.terminate_instances([ids])
        
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
        @ec2.delete_security_group(@group_name)

      end

      #create a new ami from each of the instances. (generally you should only do this on 1 instance,I guess)
      def bundle()
        puts "TODO"
      end

      #snapshot any EBS volumes attached to the instances
      def snapshot()
        puts "TODO"
      end
 



      
      def set_group_perms(params)
        @ec2.authorize_security_group_IP_ingress(@group_name, 
                                                 params[:from_port], 
                                                 params[:to_port], 
                                                 params[:ip_protocol], 
                                                 params[:cidr_ip])


      end
      public :set_group_perms


      def check_group_perms(params)
        
        ip_protocol = params[:ip_protocol] or raise  CaTPAWS::EC2::Error::MissingParameter, 'ip_protocol'
        port       = params[:port]
        from_port   = params[:from_port] || port or raise CaTPAWS::EC2::Error::MissingParameter, 'from_port'
        to_port     = params[:to_port] || port or raise CaTPAWS::EC2::Error::MissingParameter, 'to_port'
        cidr_ip    = params[:cidr_ip] || '0.0.0.0/0'
        
        sec_exists = false
        sec_group = @ec2.describe_security_groups([@group_name]).shift 
        sec_group[:aws_perms].each do |perm|
          if ( ( perm[:protocol]==ip_protocol ) && 
               ( perm[:from_port]==from_port.to_s ) && 
               ( perm[:to_port] == to_port.to_s ) &&
               ( perm[:cidr_ips] == cidr_ip )
               )
            sec_exists = true
          end
        end 
        
        return sec_exists
        
      end
      public :check_group_perms

      
      #retrieve and parse the instances for this group
      def get_instances(incl_stopped=false)
        
        instances = @ec2.describe_instances.select{|x| x[:aws_groups].grep(/^@group_name$/)}
        
        if(instances.length == 0)
          raise CaTPAWS::EC2::Error::InstanceRetrieval, "No instances found in this group"
        end 
        
        unless (incl_stopped)
          instances = instances.select {|x| x[:aws_state_code] <= 16}
        end
        
        @instances = instances
       end
      private :get_instances

      def working_dir()
         return @working_dir
      end
      public :working_dir



      #returns the array of instance metadata
      def instances()
        return @instances
      end
      public :instances

      
      #getters for all the standard ec2-describe-instances info
      #all return an array of the relevant metadata ordered as per @instances
      def id( )
        return @instances.map{ |i| i[:aws_instance_id] }
      end
      public :id
        
      def state_code()
        return @instances.map {|i| i[:aws_state_code]}
      end
      public :state_code
      
      def state_name()
        return @instances.map {|i| i[:aws_state]}
      end
      public :state_name

      def ami( )
        return @instances.map{ |i| i[:aws_image_id] }
      end
      public :ami  
      
      def dns_name()
        return @instances.map{|i| i[:dns_name] }
      end
      public :dns_name

      def private_dns_name()
        return @instances.map{|i| i[:private_dns_name] }
      end
      public :private_dns_name
      
      def key_name()
        return @instances.map{|i| i[:ssh_key_name]}
      end
      public :key_name

      def type()
        return @instances.map{|i| i[:aws_instance_type]}
      end
      public :type

      def launch_time()
        return @instances.map{|i| i[:aws_launch_time]}
      end
      public :launch_time

      def availability_zone()
        return @instances.map{|i| i[:aws_availability_zone]}
      end
      public :availability_zone
      
      def ami_launch_index()
        return @instances.map{|i| i[:ami_launch_index]}
      end
      public :ami_launch_index

      def ip_address()
        return @instances.map{|i| i[:ip_address] }
      end
      public :ip_address
      
      def private_ip_address()
        return @instances.map{|i| i[:private_ip_address]}
      end
      public :private_ip_address
      
      def architecture()
        return @instances.map{|i| i[:architecture]}
      end
      public :architecture

      def root_device_type()
        return @instances.map{|i| i[:root_device_type] }
      end
      public :root_device_type

      def monitoring_state()
        return @instances.map{|i| i[:monitoring_state]}
      end
      public :monitoring_state

    end #Instances class
    
  end #EC2
end #CaTPAWS













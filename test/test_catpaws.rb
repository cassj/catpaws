require 'helper'
require 'net/ssh'

# Note to self - run individual tests with:
# ruby -I"lib:test" test/test_catpaws.rb -n  test_01_ec2_start
# Otherwise just rake test.

# This really just tests the catpaws classes, it doesn't test
# the recipes that CaTPAWS adds to Capistrano
class TestCatpaws < Test::Unit::TestCase

  # Set appropriate environment variables in ~/.bash_profile or wherever.
  def params
    
    return {
      :group_name        => 'testing',
      :group_description => 'this is a test',
      :ami               => ENV['CATPAWS_TEST_AMI'],
      :instance_type     => ENV['CATPAWS_TEST_INSTANCE_TYPE'],
      :key               => ENV['EC2_KEY'],
      :key_file          => ENV['EC2_KEYFILE'],
      :access_key        => ENV['AMAZON_ACCESS_KEY'],
      :secret_access_key => ENV['AMAZON_SECRET_ACCESS_KEY'],
      :ec2_url           => ENV['EC2_URL'],
      :nhosts            => 2,
      :working_dir       => '/mnt/test',
      :catpaws_logfile   => 'catpaws.log'
    }
  end 

  #start a couple of instances 
  def test_01_ec2_start
    instances = CaTPAWS::EC2::Instances.new(params())
                                                
    assert_instance_of( CaTPAWS::EC2::Instances, instances, 'instances instanciation' )
    
    #check all the accessors give you back something sane (TODO)
    assert_equal(instances.id.length, 2, 'Number of instance IDs')
    assert_equal(instances.state_code.length, 2, 'Number of state codes')
    assert_equal(instances.state_name.length, 2, 'Number of state name')
    assert_equal(instances.ami.length, 2, 'Number of ami')
    assert_equal(instances.dns_name.length, 2, 'Number of dns name')
    assert_equal(instances.private_dns_name.length, 2, 'Number of private dns name')
    assert_equal(instances.key_name.length, 2, 'Number of key name' )
    assert_equal(instances.launch_time.length, 2, 'Number of launch time')
    assert_equal(instances.availability_zone.length, 2, 'Number of availability zone')
    assert_equal(instances.ami_launch_index.length, 2, 'Number of launch index')
    assert_equal(instances.ip_address.length, 2, 'Number of ip address')
    assert_equal(instances.private_ip_address.length, 2, 'Number of private ip address')
    assert_equal(instances.architecture.length, 2, 'Number of architecture')
    assert_equal(instances.root_device_type.length, 2, 'Number of root device type')
    assert_equal(instances.monitoring_state.length, 2, 'Number of monitoring state length')

    assert_instance_of( RightAws::Ec2, instances.ec2, 'Grab EC2 handle' )
    
  end


  def test_02_ec2_ssh
    params = params()
    params[:no_new] = true
    instances = CaTPAWS::EC2::Instances.new(params)
                                                
    instances.dns_name.each do |dns|
      
      #not sure how else to test this.
      assert_nothing_raised( Exception ) { 
        
        Net::SSH.start(dns, ENV['CATPAWS_TEST_USER'], :keys => [ENV['EC2_KEYFILE']]) do |ssh|
          output = ssh.exec!("hostname")
        end
      }
      
    end
  end

  
  def test_03_attach_ebs
    
    params = params()
    params[:no_new] = true
    instances = CaTPAWS::EC2::Instances.new(params)

  end


  def test_04_list_tags
    params = params()
    params[:no_new] = true
    instances = CaTPAWS::EC2::Instances.new(params)
    ec2 = instances.ec2

    ec2.create_tags('atag', 'a value', 'i-3C43067A',
                    'atag2', 'another value', 'i-3C43067A')
    
  end




  #shutdown the ec2 instances
  def test_999_ec2_stop
    
    params = params()
    params[:no_new] = true
    instances = CaTPAWS::EC2::Instances.new(params)

    #just check stop doesn't raise anything. Not sure how to test more
    assert_nothing_raised( Exception ) { instances.shutdown() }
  end


end

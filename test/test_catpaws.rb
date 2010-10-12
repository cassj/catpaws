require 'helper'

class TestCatpaws < Test::Unit::TestCase
  
  def test_ec2_start_stop
    instances = CaTPAWS::EC2::Instances.new(
                                            :group_name        => 'testing',
                                            :group_description => 'this is a test',
#                                            :ami               => 'ami-cf4d67bb',
                                            :ami               => 'emi-0243110F',
                                            :instance_type     => 'm1.small',
                                            :key               => ENV['EC2_KEY'],
                                            :key_file          => ENV['EC2_KEYFILE'],
                                            :nhosts            => 2,
                                            :access_key        => ENV['AMAZON_ACCESS_KEY'],
                                            :secret_access_key => ENV['AMAZON_SECRET_ACCESS_KEY'],
                                            :ec2_url           => ENV['EC2_URL'],
                                            :working_dir       => '/mnt/test'
                                            )
    
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

    #just check stop doesn't raise anything. Not sure how to test more
    assert_nothing_raised( Exception ) { instances.shutdown() }
  end

end

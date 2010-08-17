###
# An example Capfile using catpaws

require '/space/cassj/catpaws/lib/catpaws/ec2'


# config for catpaws

# using set :variable_name will set the value permanently
# using set_default :variable_name will let you override the 
# value using -S variable_name=value when you call a task

set :aws_access_key,  ENV['AMAZON_ACCESS_KEY']
set :aws_secret_access_key , ENV['AMAZON_SECRET_ACCESS_KEY']
set :ec2_url, ENV['EC2_URL']
set :ssh_options, { :user => "ubuntu", }

#define the master node as localhost. 
role(:master, 'localhost')












# groups

# If you only want a single group you can define settings with just
# set :group_name, "blah" and so on.

set :key, 'cassj'
set :key_file, '/home/cassj/ec2/cassj.pem'
set :ami, 'ami-cf4d67bb' #23-bit ubuntu server
set :instance_type, 'm1.small'
set :group_name, 'foo'


# If you need multiple groups, wrap their settings in a task and use *before*
# Unlike Rake, tasks can be called multiple times in a single workflow so you 
# can chop and change settings. Just be careful about the order of your before tasks
# though - it's easy to end up running stuff with the wrong group settings


task :set_group_testing, :roles => :master do
  set :key, 'cassj'
  set :key_file, '/home/cassj/ec2/cassj.pem'
  set :ami, 'ami-cf4d67bb' #23-bit ubuntu server
  set :instance_type, 'm1.small'
  set :group_name, 'testing'
end

task :set_group_foo, :roles => :master do
  set :key, 'cassj'
  set :key_file, '/home/cassj/ec2/cassj.pem'
  set :ami, 'ami-cf4d67bb' #23-bit ubuntu server
  set :instance_type, 'm1.small'
  set :group_name, 'foo'
end



# example group switching tasks:

task :a, :roles => :master do
  puts "in a"
  gn = fetch :group_name
  puts  "group "+gn
end 
before "a", "set_group_testing"

task :b, :roles => :master do
  puts "in b"
  gn = fetch :group_name
  puts "group "+ gn
end
before "b", "set_group_foo"

desc "a task to show group switching"
task :do_group_switch, :roles => :master do
  puts "in do_group_switch"
  gn = fetch :group_name
  puts "group "+gn
end 
before "do_group_switch", "a","b", "set_group_testing" 




#example fetching the status file from an ec2 instance
#not quite sure what to do with this. Should they be atts? 
#will thing further tomorrow
desc "status file test"
task :stat_file, :roles=> :foo do
  instances = fetch :instances
  status_file = instances.status_file
  status = JSON.parse(capture("cat #{status_file}"))
  puts status
end 
before "stat_file", "EC2:start"



desc "a test"
task :foo, :roles => :master do
  instances = fetch :instances
#  puts instances.dns_name
end
before "foo", "set_group_foo"
before "foo", "EC2:start"



# the EC2 security groups are mapped to cap roles 
# we can choose to run a task on all machines with a given
# with cap function find_servers

task :run_script, :hosts => proc { return ["master"]} do
 servers = find_servers()
  puts servers
end
before "run_script", "set_group_testing", "EC2:start"


###
# An example Capfile using catpaws

#require '/space/cassj/catpaws/lib/catpaws/ec2'
require 'catpaws/ec2'

# config for catpaws

# using set :variable_name will set the value permanently
# using set_default :variable_name will let you override the 
# value using -S variable_name=value when you call a task

set :aws_access_key,  ENV['AMAZON_ACCESS_KEY']
set :aws_secret_access_key , ENV['AMAZON_SECRET_ACCESS_KEY']
set :ec2_url, ENV['EC2_URL']
set :ssh_options, { :user => "ubuntu", }
set :nhosts, 2
set :status_file, '/home/ubuntu/catpaws_status.json'

#define the master node as localhost. 
role(:master, 'localhost')



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




# we've overridden find_servers_for_tasks to let you do something like:

desc "long task test"
task :long_task, :roles => :foo do

  instances = fetch :instances
  status_file = instances.status_file
  tmp_status_file = status_file+'.tmp'

  #fake a long run
  sleep(10)

  #note that we don't provide the ability to write to the file easily from here - it's deliberate - only
  #the running job should be editing the file and it can do it in whatever language it is using

  #install the perl json handler
  sudo "apt-get install libjson-perl -y"

  #slurp file contents, alter and spit them our again.
  run %Q/ perl -0 -MJSON -p -e '$stat = from_json($_); $stat->{long_task_status}="COMPLETE"; $_ = to_json($stat, {pretty=>1});'  < #{status_file}  > #{tmp_status_file} /
  run "mv #{tmp_status_file} #{status_file}"
  
end
before :long_task, 'EC2:start'
before :long_task, 'EC2:update_instance_status'


#if we cal this, it'll call long task and wait unti it has run 
#but I think it'll only wait until it's run on a single machine - need
#to make find_server_for_tasks smarter.
desc "after long task test"
task :long_task_wait, :roles => :foo, :long_task_status => 'COMPLETE' do
  instances = fetch :instances
  puts instances.status
end
before :long_task_wait, :long_task

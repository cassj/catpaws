require 'rubygems'
require 'rake'

begin
  require 'jeweler'
  Jeweler::Tasks.new do |gem|
    gem.name = "catpaws"
    gem.summary = %Q{CApistrano Tasks Pertaining to AWS}
    gem.description = %Q{Capistrano tasks to make it easy to start and stop ec2 machines on which you can run subsequent tasks, transfer data to s3 and so on}
    gem.files = ["lib/catpaws/common.rb","lib/catpaws/ec2.rb"]
    gem.email = "cassjohnston@gmail.com"
    gem.homepage = "http://github.com/cassj/catpaws"
    gem.authors = ["cassj"]
    gem.add_development_dependency "thoughtbot-shoulda", ">= 0"
    gem.add_dependency('amazon-ec2', '>= 0')
    gem.add_dependency('json', '>= 0')
  end
  Jeweler::GemcutterTasks.new
rescue LoadError
  puts "Jeweler (or a dependency) not available. Install it with: gem install jeweler"
end

require 'rake/testtask'
Rake::TestTask.new(:test) do |test|
  test.libs << 'lib' << 'test'
  test.pattern = 'test/**/test_*.rb'
  test.verbose = true
end

begin
  require 'rcov/rcovtask'
  Rcov::RcovTask.new do |test|
    test.libs << 'test'
    test.pattern = 'test/**/test_*.rb'
    test.verbose = true
  end
rescue LoadError
  task :rcov do
    abort "RCov is not available. In order to run rcov, you must: sudo gem install spicycode-rcov"
  end
end

task :test => :check_dependencies

task :default => :test

require 'rake/rdoctask'
Rake::RDocTask.new do |rdoc|
  version = File.exist?('VERSION') ? File.read('VERSION') : ""

  rdoc.rdoc_dir = 'rdoc'
  rdoc.title = "catpaws #{version}"
  rdoc.rdoc_files.include('README*')
  rdoc.rdoc_files.include('lib/**/*.rb')
end

# Generated by jeweler
# DO NOT EDIT THIS FILE DIRECTLY
# Instead, edit Jeweler::Tasks in Rakefile, and run the gemspec command
# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{catpaws}
  s.version = "0.0.1"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["cassj"]
  s.date = %q{2010-08-18}
  s.description = %q{Capistrano tasks to make it easy to start and stop ec2 machines on which you can run subsequent tasks, transfer data to s3 and so on}
  s.email = %q{cassjohnston@gmail.com}
  s.extra_rdoc_files = [
    "LICENSE",
     "README.rdoc"
  ]
  s.files = [
    "lib/catpaws.rb",
     "lib/catpaws/base.rb",
     "lib/catpaws/base/cap.rb",
     "lib/catpaws/base/catpaws.rb",
     "lib/catpaws/ec2.rb",
     "lib/catpaws/ec2/cap.rb",
     "lib/catpaws/ec2/catpaws.rb"
  ]
  s.homepage = %q{http://github.com/cassj/catpaws}
  s.rdoc_options = ["--charset=UTF-8"]
  s.require_paths = ["lib"]
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{CApistrano Tasks Pertaining to AWS}
  s.test_files = [
    "test/helper.rb",
     "test/test_catpaws.rb"
  ]

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_development_dependency(%q<thoughtbot-shoulda>, [">= 0"])
      s.add_runtime_dependency(%q<capistrano>, [">= 2"])
      s.add_runtime_dependency(%q<amazon-ec2>, [">= 0"])
      s.add_runtime_dependency(%q<json>, [">= 0"])
    else
      s.add_dependency(%q<thoughtbot-shoulda>, [">= 0"])
      s.add_dependency(%q<capistrano>, [">= 2"])
      s.add_dependency(%q<amazon-ec2>, [">= 0"])
      s.add_dependency(%q<json>, [">= 0"])
    end
  else
    s.add_dependency(%q<thoughtbot-shoulda>, [">= 0"])
    s.add_dependency(%q<capistrano>, [">= 2"])
    s.add_dependency(%q<amazon-ec2>, [">= 0"])
    s.add_dependency(%q<json>, [">= 0"])
  end
end


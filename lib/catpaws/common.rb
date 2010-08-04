require 'rubygems'
require 'fileutils'
require 'AWS'
require 'json'

def _cset(name, *args, &block)
  unless exists?(name)
    set(name, *args, &block)
  end
end

#Generic on load stuff
Capistrano::Configuration.instance(:must_exist).load do

  # User AWS details
  _cset (:access_key) {abort "Please specify your amazon access key, set :access_key, 'access_key'"}
  _cset (:secret_access_key) {abort "Please specify your amazon secret access key, set :secret_access_key, 'secret access key'"}
  
  # localhost as master node by default
  _cset (:master) {'localhost'}

end





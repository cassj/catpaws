require('/space/cassj/catpaws/lib/catpaws/base/catpaws')

# include the CaTPAWS module in Cap config  
Capistrano::Configuration.send(:include, CaTPAWS)

# and setup stuff common to all the catpaws cap stuff
Capistrano::Configuration.instance(:must_exist).load do

  # User AWS details
  set_default (:access_key) {abort "Please specify your amazon access key, set :access_key, 'access_key'"}
  set_default (:secret_access_key) {abort "Please specify your amazon secret access key, set :secret_access_key, 'secret access key'"}
  
  # localhost as master node by default
  set_default (:master) {'localhost'}
  
end


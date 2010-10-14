require('catpaws/base/catpaws')
require('pp')

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


module Capistrano
  class Configuration
    module Servers

      def find_servers_for_task(task, options={})
              
        attempts  = options[:attempts].to_i || 1
        wait_time = options[:wait_time].to_i || 10
        options.delete(:attempts)
        options.delete(:wait_time)
        
        servers = find_servers(task.options.merge(options))
        attempt = 1

        while(servers.length == 0 && attempt <= attempts)
          wait(wait_time)
          servers = find_servers(task.options.merge(options))
          attempts += 1
        end
        
        return servers

      end

    end
  end
end


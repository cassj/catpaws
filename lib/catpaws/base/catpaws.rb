require 'rubygems'
require 'fileutils'
require 'right_aws'
require 'json'
require 'uri'

module CaTPAWS

  #generic catpaws error classes
  module Error
    AWSError = Class.new(StandardError)
  end
  
  #mess about with parent module. 
  def self.included(base)
    def set_default(name, *args, &block)
      unless exists?(name)
        set(name, *args, &block)
      end
    end
  end
  
end




require 'rubygems'
require 'test/unit'
require 'shoulda'

$LOAD_PATH.unshift(File.join(File.dirname(__FILE__), '..', 'lib'))
$LOAD_PATH.unshift(File.dirname(__FILE__))

#there's no point in trying to test the capistrano stuff outside of 
#capistrano, but we can test the catpaws classes
require 'catpaws/ec2/catpaws'

class Test::Unit::TestCase
end

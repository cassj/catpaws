require '/space/cassj/catpaws/lib/catpaws/ec2/catpaws'


instances = CaTPAWS::EC2::Instances.new(:group_name        => "testing",
                                        :group_description => "this is a test",
                                        :ami               => "ami-cf4d67bb",
                                        :instance_type     => "m1.small",
                                        :key               => "cassj",
                                        :nhosts            => 2,
                                        :access_key        => "16F5AHH5HWR243WSNMR2",
                                        :secret_access_key => "TNza1pTtle8CoKG1anJJI6cN0ebe6xi14iFc9jFh")

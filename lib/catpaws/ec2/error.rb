module CaTPAWS
  module EC2

    #errors
    module Error
      MissingParamter = Class.new(CaTPAWS::Error::AWSError)
      InstanceError = Class.new(CaTPAWS::Error::AWSError)
    end
    
  end
end

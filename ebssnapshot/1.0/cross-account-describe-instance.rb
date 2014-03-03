#!/usr/bin/env ruby
require 'rubygems'
require 'aws-sdk'
require 'optparse'

access_key_id = nil
secret_access_key = nil
endpoint = 'ap-northeast-1'
assume_role_arn = nil
assume_role_session_name = 'ebssnapshotsession'

opt = OptionParser.new
opt.on('-a', '--access-key-id=VAL') { |v| acccess_key_id = v }
opt.on('-s', '--secret-access-key=VAL') { |v| secret_access_key = v }
opt.on('-r', '--assume-role-arn=VAL') { |v| assume_role_arn = v }
opt.on('-e', '--endpoint=VAL', "Default:#{endpoint}") { |v| endpoint = v }
opt.parse!

# Get STS Object
sts = AWS::STS.new

# Call AssumeRole to temprarily get permitted
assume_info =  sts.assume_role(
  role_arn: assume_role_arn,
  role_session_name: assume_role_session_name,
)

# Overwrite permission
AWS.config({
  access_key_id: assume_info[:credentials][:access_key_id],
  secret_access_key: assume_info[:credentials][:secret_access_key],
  session_token: assume_info[:credentials][:session_token],
})

AWS.memoize{
  print "started: " + Time.now.to_s + "\n"
  ec2 = AWS::EC2.new
  ec2.regions.each {|r|
    print "#{r.name}\n"
    r.instances.each {|i|
      print "  instance:\t#{i.id},#{i.tags['Name']},#{i.status},#{i.key_name}"
      if i.status_code == 16
        print ",#{(Time.now.utc.to_i - i.launch_time.to_i).divmod(60*60)[0]}h,#{i.ip_address}\n"
      else
        print ",0h\n"
      end
    }
  }
}

print "finished: " + Time.now.to_s + "\n"

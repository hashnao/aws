#!/bin/env  ruby
require 'rubygems'
require 'aws-sdk'
require 'optparse'

option = Hash.new

def usage
  STDERR.printf <<EOT
#{$0}: missing option
Try '#{$0} --help' for more information.
EOT
end
 
if ARGV[0].nil?
  usage
  exit 0
end

endpoint = 'ap-northeast-1'
assume_role_arn = nil
assume_role_session_name = 'ebssnapshotsession'
volume_id = nil
time_now = Time.now
description = "#{time_now.strftime("%Y/%m/%d %H:%M:%S backuped by #{$0}")}"
name = nil
generation = nil

opt = OptionParser.new
opt.on('-e', '--endpoint=VAL', "default:#{endpoint}") { |v| endpoint = v }
opt.on('-g', '--genaration=VAL', ':ex. --generation 4 (default: all snapshots remain.') { |v| generation = v.to_i }
opt.on('-n', '--snapshot-name=VAL',
       "default:#{time_now.strftime("[volume_id]-%Y/%m/%d_%H:%M:%S")}") { |v| name = v }
opt.on('-r', '--assume-role-arn=VAL') { |v| assume_role_arn = v }
opt.on('-s', '--secret-access-key=VAL') { |v| secret_access_key = v }
opt.on('-v', '--volume-id=VAL') { |v| volume_id = v }
opt.parse!

name = time_now.strftime("#{volume_id}-%Y/%m/%d_%H:%M:%S") unless name
raise "--volume-id is necessary,-h or --help option" unless volume_id
raise "--assume-role-ar is necessary,-h or --help option" unless assume_role_arn

# Get STS Object
sts = AWS::STS.new

# Call AssumeRole to temprarily get permitted
session_duration = 60*60
assume_info = sts.assume_role(
  role_arn: assume_role_arn,
  role_session_name: assume_role_session_name,
  duration_seconds: session_duration,
)

# Overwrite permission
AWS.config({
  access_key_id: assume_info[:credentials][:access_key_id],
  secret_access_key: assume_info[:credentials][:secret_access_key],
  session_token: assume_info[:credentials][:session_token],
  :max_retries => 3,
})

# Create EBS snapshot
ec2 = AWS::EC2.new
reg = ec2.regions[endpoint]
snapshot = reg.volumes[volume_id].create_snapshot(description)
sleep 1 until [:completed, :error].include?(snapshot.status)
snapshot.add_tag('Name', :value => name)

# Describe snapshot status
puts "#{name} Snapshot iD: #{snapshot.id}, Progress: #{snapshot.progress}%, Status: #{snapshot.status}"

# Rotate and Delete EBS snapshot
if generation
  snapshots = reg.snapshots.filter('volume-id', volume_id).sort_by { |x| x.start_time }.reverse
  ss = snapshots[generation..-1]
  ss.each { |x| x.delete } unless ss.nil?
end

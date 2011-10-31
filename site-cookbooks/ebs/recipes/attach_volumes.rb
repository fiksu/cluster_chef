# aws included via metadata.rb
# but in order to get right_aws gem installed, we should require it here as well

include_recipe 'aws'

if node[:ebs_volumes]
  node[:ebs_volumes].each do |name, conf|
    aws_ebs_volume "attach EBS volume #{conf.inspect}" do
      provider "aws_ebs_volume"
      aws_access_key        node[:aws][:aws_access_key]
      aws_secret_access_key node[:aws][:aws_secret_access_key]
      availability_zone     node[:aws][:availability_zone]
      device                conf[:device]

      if conf[:volume_id]
        volume_id             conf[:volume_id]
        action :attach
      else
        snapshot_id           conf[:snapshot_id]
        action [:create, :attach]
      end
    end
  end
end

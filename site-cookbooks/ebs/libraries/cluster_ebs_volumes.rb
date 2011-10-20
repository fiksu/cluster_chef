module ClusterEbsVolumes
  # ebs volume mapping for this node
  def cluster_ebs_volumes
    all_cluster_volumes[node[:cluster_role].to_s][node[:cluster_role_index].to_i] rescue []
  end

  # all ebs volumes for this cluster
  def all_cluster_volumes
    data_bag_item('cluster_ebs_volumes', node[:cluster_name]) rescue {}
  end

  def log_cluster_volume_info desc
    Chef::Log.info [
      desc,
      node[:cluster_name],       node[:cluster_role],
      node[:cluster_role_index], node[:ec2][:ami_launch_index],
      all_cluster_volumes, cluster_ebs_volumes,
    ].inspect
  end

  # Use `file -s` to identify volume type: ohai doesn't seem to want to do so.
  def fstype_from_file_magic(dev)
    return 'ext3' unless File.exists?(dev)
    dev_type_str = `file -s '#{dev}'`
    case
    when dev_type_str =~ /SGI XFS/           then 'xfs'
    when dev_type_str =~ /Linux.*ext3/       then 'ext3'
    else                                          'ext3'
    end
  end
end

class Chef::Recipe ;              include ClusterEbsVolumes ; end
class Chef::Resource::Directory ; include ClusterEbsVolumes ; end
class Chef::Resource            ; include ClusterEbsVolumes ; end
class Chef::Resource::Template  ; include ClusterEbsVolumes ; end

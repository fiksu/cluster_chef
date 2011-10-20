module HadoopCluster

  # Template variables
  def template_variables(wait = false)
    template_vars = node[:hadoop][:template_variables]
    unless template_vars
      node.set[:hadoop][:template_variables] = {
        :namenode_address       => namenode_address(wait),
        :jobtracker_address     => jobtracker_address(wait),
        :mapred_local_dirs      => mapred_local_dirs.join(','),
        :dfs_name_dirs          => dfs_name_dirs.join(','),
        :dfs_data_dirs          => dfs_data_dirs.join(','),
        :fs_checkpoint_dirs     => fs_checkpoint_dirs.join(','),
        :local_hadoop_dirs      => local_hadoop_dirs,
        :persistent_hadoop_dirs => persistent_hadoop_dirs,
        :all_cluster_volumes    => all_cluster_volumes,
        :cluster_ebs_volumes    => cluster_ebs_volumes,
        :ganglia                => ganglia_address,
       :ganglia_address        => ganglia_address,
        :ganglia_port           => 8649,
      }
       node.save
       template_vars = node[:hadoop][:template_variables]
       Chef::Log.info "template_variables: #{template_vars.inspect}"
    end
    return template_vars
  end

  # The namenode's hostname, or the local node's numeric ip if 'localhost' is given
  def namenode_address(wait = false)
    provider_private_ip("#{node[:cluster_name]}-namenode", wait)
  end

  # The jobtracker's hostname, or the local node's numeric ip if 'localhost' is given
  def jobtracker_address(wait = false)
    provider_private_ip("#{node[:cluster_name]}-jobtracker", wait)
  end

  # Ganglia hostname
  def ganglia_address(wait = false)
    provider_private_ip("#{node[:cluster_name]}-gmetad", wait)
  end

  def hadoop_package component
    package_name = (component ? "#{node[:hadoop][:hadoop_handle]}-#{component}" : "#{node[:hadoop][:hadoop_handle]}")
    package package_name do
      if node[:hadoop][:deb_version] != 'current'
        version node[:hadoop][:deb_version]
      end
    end
  end

  # Make a hadoop-owned directory
  def make_hadoop_dir dir, dir_owner, dir_mode="0755"
    directory dir do
      owner    dir_owner
      group    "hadoop"
      mode     dir_mode
      action   :create
      recursive true
    end
  end

  def make_hadoop_dir_on_ebs dir, dir_owner, dir_mode="0755"
    directory dir do
      owner    dir_owner
      group    "hadoop"
      mode     dir_mode
      action   :create
      recursive true
      only_if{ cluster_ebs_volumes_are_mounted? }
    end
  end

  def ensure_hadoop_owns_hadoop_dirs dir, dir_owner, dir_mode="0755"
    execute "Make sure hadoop owns hadoop dirs" do
      command %Q{chown -R #{dir_owner}:hadoop #{dir}}
      command %Q{chmod -R #{dir_mode}         #{dir}}
      not_if{ (File.stat(dir).uid == dir_owner) && (File.stat(dir).gid == 300) }
    end
  end

  # Create a symlink to a directory, wiping away any existing dir that's in the way
  def force_link dest, src
    directory(dest) do
      action :delete ; recursive true
      not_if{ File.symlink?(dest) }
    end
    link(dest){ to src }
  end

  def local_hadoop_dirs
    dirs = node[:hadoop][:local_disks].map{|mount_point, device| mount_point+'/hadoop' }
    dirs.unshift('/mnt/hadoop') if node[:hadoop][:use_root_as_scratch_vol]
    dirs.uniq
  end

  def persistent_hadoop_dirs
    if node[:hadoop][:ignore_ebs_volumes] or cluster_ebs_volumes.nil?
      (['/mnt/hadoop'] + local_hadoop_dirs).uniq
    else
      dirs = cluster_ebs_volumes.map{|vol_info| vol_info['mount_point']+'/hadoop' }
      dirs.unshift('/mnt/hadoop') if node[:hadoop][:use_root_as_persistent_vol]
      dirs.uniq
    end
  end

  def cluster_ebs_volumes_are_mounted?
    return true if cluster_ebs_volumes.nil?
    cluster_ebs_volumes.all?{|vol_info| File.exists?(vol_info['device']) }
  end

  # The HDFS data. Spread out across persistent storage only
  def dfs_data_dirs
    persistent_hadoop_dirs.map{|dir| File.join(dir, 'hdfs/data')}
  end
  # The HDFS metadata. Keep this on two different volumes, at least one persistent
  def dfs_name_dirs
    dirs = persistent_hadoop_dirs.map{|dir| File.join(dir, 'hdfs/name')}
    unless node[:hadoop][:extra_nn_metadata_path].nil?
      dirs << File.join(node[:hadoop][:extra_nn_metadata_path].to_s, node[:cluster_name], 'hdfs/name')
    end
    dirs
  end
  # HDFS metadata checkpoint dir. Keep this on two different volumes, at least one persistent.
  def fs_checkpoint_dirs
    dirs = persistent_hadoop_dirs.map{|dir| File.join(dir, 'hdfs/secondary')}
    unless node[:hadoop][:extra_nn_metadata_path].nil?
      dirs << File.join(node[:hadoop][:extra_nn_metadata_path].to_s, node[:cluster_name], 'hdfs/secondary')
    end
    dirs
  end
  # Local storage during map-reduce jobs. Point at every local disk.
  def mapred_local_dirs
    local_hadoop_dirs.map{|dir| File.join(dir, 'mapred/local')}
  end

end

class Chef::Recipe
  include HadoopCluster
end
class Chef::Resource::Directory
  include HadoopCluster
end
class Chef::Resource::Template
  include HadoopCluster
end

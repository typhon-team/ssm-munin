# munin::node - Configure a munin node, and export configuration a
# munin master can collect.
#
# Parameters:
#
# allow: List of IPv4 and IPv6 addresses and networks to allow to connect.
#
# config_root: Root directory for munin configuration.
#
# nodeconfig: List of lines to append to the munin node configuration.
#
# host_name: The host name munin node identifies as. Defaults to
# the $::fqdn fact.
#
# log_dir: The log directory for the munin node process. Defaults
# change according to osfamily, see munin::params::node for details.
#
# log_file: Appended to "log_dir". Defaults to "munin-node.log".
#
# log_destination: "file" or "syslog".  Defaults to "file".  If log_destination
# is "syslog", the "log_file" and "log_dir" parameters are ignored, and the
# "syslog_*" parameters are used if set.
#
# purge_configs: Removes all other munin plugins and munin plugin
# configuration files.  Boolean, defaults to false.
#
# syslog_facility: Defaults to undef, which makes munin-node use the
# perl Net::Server module default of "daemon". Possible values are any
# syslog facility by number, or lowercase name.
#
# masterconfig: List of configuration lines to append to the munin
# master node definitinon
#
# mastername: The name of the munin master server which will collect
# the node definition.
#
# mastergroup: The group used on the master to construct a FQN for
# this node. Defaults to "", which in turn makes munin master use the
# domain. Note: changing this for a node also means you need to move
# rrd files on the master, or graph history will be lost.
#
# plugins: A hash used by create_resources to create munin::plugin
# instances.
#
# address: The address used in the munin master node definition.
#
# bind_address: The IP address the munin-node process listens on. Defaults: *.
#
# bind_port: The port number the munin-node process listens on.
#
# package_name: The name of the munin node package to install.
#
# service_name: The name of the munin node service.
#
# service_ensure: Defaults to "". If set to "running" or "stopped", it
# is used as parameter "ensure" for the munin node service.
#
# export_node: "enabled" or "disabled". Defaults to "enabled".
# Causes the node config to be exported to puppetmaster.
#
# file_group: The UNIX group name owning the configuration files,
# log files, etc.
#
# timeout: Used to set the global plugin runtime timeout for this
# node. Integer. Defaults to undef, which lets munin-node use its
# default of 10 seconds.

class munin::node (
  String $address                                                                                                                       = $munin::params::node::address,
  Array[String] $allow                                                                                                                  = $munin::params::node::allow,
  String $bind_address                                                                                                                  = $munin::params::node::bind_address,
  Integer $bind_port                                                                                                                    = $munin::params::node::bind_port,
  String $config_root                                                                                                                   = $munin::params::node::config_root,
  String $host_name                                                                                                                     = $munin::params::node::host_name,
  String $log_dir                                                                                                                       = $munin::params::node::log_dir,
  String $log_file                                                                                                                      = $munin::params::node::log_file,
  Array[String] $masterconfig                                                                                                           = $munin::params::node::masterconfig,
  Variant[Undef, String] $mastergroup                                                                                                   = $munin::params::node::mastergroup,
  Variant[Undef, String] $mastername                                                                                                    = $munin::params::node::mastername,
  Array[String] $nodeconfig                                                                                                             = $munin::params::node::nodeconfig,
  String $package_name                                                                                                                  = $munin::params::node::package_name,
  Hash $plugins                                                                                                                         = $munin::params::node::plugins,
  Boolean $purge_configs                                                                                                                = $munin::params::node::purge_configs,
  Variant[Undef, Enum['running','stopped']] $service_ensure                                                                             = $munin::params::node::service_ensure,
  String $service_name                                                                                                                  = $munin::params::node::service_name,
  Enum['enabled','disabled'] $export_node                                                                                               = $munin::params::node::export_node,
  String $file_group                                                                                                                    = $munin::params::node::file_group,
  Enum['file','syslog'] $log_destination                                                                                                = $munin::params::node::log_destination,
  Variant[Undef, Regexp[/^(?:\d+|(?:kern|user|mail|daemon|auth|syslog|lpr|news|uucp|authpriv|ftp|cron|local[0-7]))$/]] $syslog_facility = $munin::params::node::syslog_facility,
  Variant[Undef, Integer] $timeout                                                                                                      = $munin::params::node::timeout,
) inherits munin::params::node {

  case $log_destination {
    'file': {
      $_log_file = "${log_dir}/${log_file}"
      assert_type(Stdlib::Compat::Absolute_Path, $_log_file)
    }
    'syslog': {
      $_log_file = 'Sys::Syslog'
    }
    default: {
      fail('log_destination is not set')
    }
  }

  if $mastergroup {
    $fqn = "${mastergroup};${host_name}"
  }
  else {
    $fqn = $host_name
  }

  if $service_ensure { $_service_ensure = $service_ensure }
  else { $_service_ensure = undef }

  # Defaults
  File {
    ensure => present,
    owner  => 'root',
    group  => $file_group,
    mode   => '0444',
  }

  package { $package_name:
    ensure => installed,
  }

  service { $service_name:
    ensure  => $_service_ensure,
    enable  => true,
    require => Package[$package_name],
  }

  file { "${config_root}/munin-node.conf":
    content => template('munin/munin-node.conf.erb'),
    require => Package[$package_name],
    notify  => Service[$service_name],
  }

  # Export a node definition to be collected by the munin master.
  # (Separated into its own class to prevent warnings about "missing
  # storeconfigs", even if $export_node is not enabled)
  if $export_node == 'enabled' {
    class { '::munin::node::export':
      address      => $address,
      fqn          => $fqn,
      mastername   => $mastername,
      masterconfig => $masterconfig,
    }
  }

  # Generate plugin resources from hiera or class parameter.
  create_resources(munin::plugin, $plugins, {})

  # Purge unmanaged plugins and plugin configuration files.
  if $purge_configs {
    file { ["${config_root}/plugins", "${config_root}/plugin-conf.d" ]:
      ensure  => directory,
      recurse => true,
      purge   => true,
      require => Package[$package_name],
      notify  => Service[$service_name],
    }
  }

}

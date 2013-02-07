# == Class: stingray
#
# This class will download and install the Stingray Traffic Manager
# onto a node.
#
# === Parameters
#
# [*tmp_dir*]
# Temp directory to use during installation.  Defaults to '/tmp'.
#
# [*install_dir*]
# Directory on the target node to install the Stingray software to.
# Defaults to '/usr/local/stingray/'.
#
# [*version*]
# The version of Stingray to install.  Defaults to '9.1'.
#
# [*accept_license*]
# Use of this software is subject to the terms of the Riverbed End User
# License Agreement
#
# Please review these terms, published at http://www.riverbed.com/license
# before proceeding.
#
# Set this to to 'accept' once you have read the license.
#
# === Examples
#
#  class { 'stingray':
#      accept_license => 'accept'
#  }
#
# === Authors
#
# Faisal Memon <fmemon@riverbed.com>
#
# === Copyright
#
# Copyright 2013 Riverbed Technology
#
class stingray (
    $tmp_dir = $stingray::params::tmp_dir,
    $install_dir = $stingray::params::install_dir,
    $version = $stingray::params::version,
    $accept_license = 'accept'
    #$accept_license = $stingray::params::accept_license

) inherits stingray::params {

    package {
        'wget':;
    }

    Exec { path => '/usr/bin:/bin:/usr/sbin:/sbin' }

    #
    # This block of code will format the URL to download the Stingray
    # installer based on $version.
    #
    $image_loc = "https://support.riverbed.com/download.htm?filename=public/software/stingray/trafficmanager/${version}"
    $temp_ver = regsubst($version, '(.*)\.(.*)', '\1\2')
    $image_name = "ZeusTM_${temp_ver}_Linux-${stingray::params::stm_arch}"

    #
    # Download from Riverbed Support site and place in $tmp_dir
    #
    exec { "wget ${image_loc}/${image_name}.tgz -O ${tmp_dir}/${image_name}.tgz":
        creates => "${tmp_dir}/${image_name}.tgz",
        require => [Package[wget], ],
        alias   => 'wget_stingray',
    }

    #
    # Untar and Ungzip the Stingray installer
    #
    exec { "tar zxvf ${tmp_dir}/${image_name}.tgz":
        cwd     => $tmp_dir,
        creates => "${tmp_dir}/${image_name}/",
        require => [ Exec['wget_stingray'], ],
        alias   => 'untar_stingray',
    }

    #
    # Create the installer script
    #
    file { "${tmp_dir}/${image_name}/install_script":
        content => template('stingray/stingray_install.erb'),
        require => [ Exec['untar_stingray'], ],
        alias   => 'create_install_script',
    }

    #
    # And finally install the software
    #
    exec { "${tmp_dir}/${image_name}/zinstall --replay-from=install_script --noninteractive":
        cwd     => $tmp_dir,
        user    => 'root',
        creates => "${install_dir}/zxtm-${version}",
        require => [ File['create_install_script'], ],
        alias   => 'install_stingray',
    }

    #
    # The next step is either create a new_cluster or join_cluster
    #

    #stingray::join_cluster{"test":
    #            join_cluster_host => "stm1",
    #            join_cluster_port => "9090",
    #            admin_password => "Im2demo4u"
    #}
    stingray::new_cluster{'new_cluster':
    }

    stingray::pool{'Northern Lights':
        nodes     => ['192.168.22.121:80', '192.168.22.122:80', '192.168.22.123:80'],
        algorithm => 'Perceptive',
        persistence => 'NL',
        monitors => ['Ping', 'NL']
    }

    stingray::virtual_server{'Northern Lights':
                pool    => 'Northern Lights',
                address => '!test_tip',
                enabled => 'yes',
    }

    stingray::virtual_server{'testing':
                #address => ['!test test', '!test_tip'],
                address => '1.2.3.4',
                port    => 81,
                enabled => 'no',
    }

    stingray::persistence{'NL':
                type => 'Transparent session affinity'
   }

    stingray::trafficipgroup{'test_tip':
                ipaddresses => '10.32.147.85',
                machines    => 'stmtest.tmktg.nbttech.com',
                enabled     => yes,
    }

    stingray::monitor{'NL':
        type => 'HTTP',
        path => '/test',
        authentication => 'fmemon:password',
	body_regex => '.*'
    }
        
    stingray::ssl_certificate{'My cert':
        certificate_file => 'puppet:///modules/stingray/company.com.public',
        private_key_file => 'puppet:///modules/stingray/company.com.private'
    }
}
# Class: bareos::database
#
# This class enforces database resources needed by all
# bareos components
#
# This class is not to be called individually
#
class bareos::database {

  include bareos

  ### Managed resources
  require bareos::repository

  package { 'bareos-database':
    ensure  => $bareos::manage_package,
    name    => "bareos-database-${bareos::database_backend}",
    noop    => $bareos::noops,
    require => Class['bareos::repository'],
  }

  if $bareos::manage_database {
    $real_db_password = $bareos::database_password ? {
      ''      => $bareos::real_default_password,
      default => $bareos::database_password,
    }

    $script_directory = '/usr/lib/bareos/scripts'

    $db_parameters = $bareos::database_backend ? {
      'sqlite' => '',
      'mysql'  => "--host=${bareos::database_host} --user=${bareos::database_user} --password=${real_db_password} --port=${bareos::database_port} --database=${bareos::database_name}",
    }

    exec { 'create_db_and_tables':
      command     => "${script_directory}/create_${bareos::database_backend}_database;
                      ${script_directory}/make_${bareos::database_backend}_tables ${db_parameters}",
      refreshonly => true,
    }

    case $bareos::database_backend {
      'mysql': {

        class  { 'mysql::server':
          root_password           => $real_db_password,
          remove_default_accounts => true,
        }

        mysql::db { $::bareos::database_name:
          user     => $::bareos::database_user,
          password => $real_db_password,
          host     => $::fqdn,
          notify   => Exec['create_db_and_tables'],
        }
        
      }
      'sqlite': {
        sqlite::db { $bareos::database_name:
          ensure   => present,
          location => "/var/lib/bareos/${bareos::database_name}.db",
          owner    => $bareos::process_user,
          group    => $bareos::process_group,
          require  => File['/var/lib/bareos'],
        }
      }
      default: {
        fail "The bareos module does not support managing the ${bareos::database_backend} backend database"
      }
    }
  }
}

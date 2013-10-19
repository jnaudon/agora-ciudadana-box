$home         = '/home/vagrant'
$app_home     = '/vagrant/agora-ciudadana'
$as_vagrant   = 'sudo -u vagrant -H bash -l -c'
$as_root      = 'sudo -H bash -l -c'

Exec {
  path => ['/usr/sbin', '/usr/bin', '/sbin', '/bin', $app_home]
}

# --- apt-get update -----------------------------------------------------------

exec { "apt_get_update":
  command => "apt-get update"
} ->

# --- Git ----------------------------------------------------------------------

package { ['git-core']:
  ensure => installed;
} ->

# --- SQLite -------------------------------------------------------------------

package { ['sqlite3', 'libsqlite3-dev']:
  ensure => installed;
} ->

# --- Python -------------------------------------------------------------------

package { ['python2.7-dev', 'virtualenvwrapper']:
  ensure => installed;
} ->

# --- RabbitMQ -----------------------------------------------------------------

package { ['rabbitmq-server']:
  ensure => installed;
} ->

# --- Utils --------------------------------------------------------------------

package { ['gettext']:
  ensure => installed;
} ->

# --- Installation -------------------------------------------------------------

exec { 'append_virtualenvwrapper_in_profile':
  command => "echo 'source /etc/bash_completion.d/virtualenvwrapper' >> $home/.profile",
  unless  => "grep 'virtualenvwrapper' -- $home/.profile"
} ->

exec { 'mkvirtualenv_agora_ciudadana':
  command => "${as_vagrant} 'mkvirtualenv agora-ciudadana'",
  cwd     => $app_home
} ->

exec { 'workon_agora_ciudadana':
  command => "${as_vagrant} 'workon agora-ciudadana'",
  cwd     => $app_home
} ->

package { ['build-essential', 'libxml2-dev', 'libxslt1-dev']:
  ensure => installed
} ->

exec { 'pip_install':
  command => "${as_root} 'pip install -r requirements.txt --upgrade'",
  cwd     => $app_home,
  timeout => 0,
  creates => "${app_home}/build"
} ->

exec { 'configure_database':
  command => 'manage.py syncdb --all',
  cwd     => $app_home
} ->

exec { 'mark_migrations_as_applied':
  command => 'manage.py migrate --fake',
  cwd     => $app_home
} ->

exec { 'rebuild_initial_django_haystack_index':
  command => 'manage.py rebuild_index --noinput',
  cwd     => $app_home
} ->

exec { 'fix_permissions':
  command => 'manage.py check_permissions',
  cwd     => $app_home
} ->

exec { 'start_celeryd':
  command => 'manage.py celeryd -l INFO -B -S djcelery.schedulers.DatabaseScheduler &',
  cwd     => $app_home
} ->

exec { 'start_webserver':
  command => 'manage.py runserver &',
  cwd     => $app_home
} ->

# --- Setup services -----------------------------------------------------------

service { 'rabbitmq-server':
  enable => true
}
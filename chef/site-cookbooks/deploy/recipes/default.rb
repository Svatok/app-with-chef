encrypted_data = Chef::EncryptedDataBagItem.load('configs', node.environment)

config = node['project']
deployer = config['user']

root_path = config['root']
shared_path = File.join(root_path, 'shared')
bundle_path = File.join(shared_path, 'vendor', 'bundle')
config_path = File.join(shared_path, 'config')
ssh_path = File.join(shared_path, '.ssh')

puma_state_file = File.join(shared_path, 'tmp', 'pids', 'puma.state')

ssh_key_file = File.join(ssh_path, deployer)
ssh_wrapper_file = File.join(ssh_path, 'wrap-ssh4git.sh')

directory ssh_path do
  owner deployer
  group deployer
  recursive true
end

cookbook_file ssh_key_file do
  source 'key'
  owner deployer
  group deployer
  mode 0o600
end

file ssh_wrapper_file do
  content "#!/bin/bash\n/usr/bin/env ssh -o \"StrictHostKeyChecking=no\" -i \"#{ssh_key_file}\" $1 $2"
  owner deployer
  group deployer
  mode 0o755
end

%w[config log public/system public/uploads repo tmp/cache tmp/pids tmp/sockets].each do |dir|
  directory File.join(shared_path, dir) do
    owner deployer
    group deployer
    mode 0o755
    recursive true
  end
end

template File.join(config_path, 'database.yml') do
  source File.join(node.environment, 'database.yml.erb')
  variables(
    environment: node.environment,
    database: encrypted_data['database']['name'],
    user: encrypted_data['database']['user'],
    password: encrypted_data['database']['password']
  )
  sensitive true
  owner deployer
  group deployer
  mode 0o644
end


# rubocop:disable Metrics/BlockLength
timestamped_deploy node['app_name'] do
  ssh_wrapper ssh_wrapper_file
  repository config['repository']
  branch config['branch']
  repository_cache 'repo'
  deploy_to config['root']
  user deployer
  group deployer

  environment(
    'RAILS_ENV' => node.environment
  )

  create_dirs_before_symlink %w[tmp public]

  symlinks(
    'config/database.yml' => 'config/database.yml',
    'log' => 'log',
    'public/system' => 'public/system',
    'public/uploads' => 'public/uploads',
    'tmp/cache' => 'tmp/cache',
    'tmp/pids' => 'tmp/pids',
    'tmp/sockets' => 'tmp/sockets'
  )

  symlink_before_migrate(
    'config/database.yml' => 'config/database.yml'
  )

  before_migrate do
    execute 'install bundler' do
      command "/bin/bash -lc 'gem install bundler'"
      cwd release_path
      user deployer
      group deployer
    end

    execute 'bundle install' do
      command "/bin/bash -lc 'bundle install \
              --without development test --deployment --path #{bundle_path}'"
      cwd release_path
      user deployer
      group deployer
    end
  end

  migration_command "/bin/bash -lc 'bundle exec rails db:migrate --trace'"
  migrate true

  if File.exist? puma_state_file
    restart_command "/bin/bash -lc 'bundle exec pumactl -S #{puma_state_file} restart'"
  end

  before_restart do
    execute 'bundle exec rake assets:precompile' do
      command "/bin/bash -lc 'RAILS_ENV=production bundle exec rake assets:precompile'"
      cwd release_path
      user deployer
      group deployer
    end
  end

  action :deploy
end

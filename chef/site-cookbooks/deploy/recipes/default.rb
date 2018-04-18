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
    'config' => 'config',
    'log' => 'log',
    'public/system' => 'public/system',
    'public/uploads' => 'public/uploads',
    'tmp/cache' => 'tmp/cache',
    'tmp/pids' => 'tmp/pids',
    'tmp/sockets' => 'tmp/sockets'
  )

  # symlink_before_migrate(
  #   'config/secrets.yml.key' => 'config/secrets.yml.key'
  # )

  # before_migrate do
  #   file maintenance_file do
  #     owner deployer
  #     group deployer
  #     action :create
  #   end
  before_restart do
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
  # end

  # migration_command "/bin/bash -lc 'source $HOME/.rvm/scripts/rvm && bundle exec rails db:migrate --trace'"
  # migrate true

  if File.exist? puma_state_file
    restart_command "/bin/bash -lc 'bundle exec pumactl -S #{puma_state_file} restart'"
  end

  before_restart do
    # execute "cd #{release_path}/client && yarn install && yarn build"
    execute 'bundle exec rake assets:precompile' do
      command "/bin/bash -lc 'RAILS_ENV=production bundle exec rake assets:precompile'"
      cwd release_path
      user deployer
      group deployer
    end
  end

  action :deploy
end

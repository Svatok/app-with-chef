execute 'add gpg2 key' do
  environment('HOME' => "/home/#{node['project']['user']}",
              'USER' => node['project']['user'])
  command 'curl -sSL https://rvm.io/mpapis.asc | gpg --import -'
end

execute 'chown ~/.gnupg' do
  command "chown -R #{node['project']['user']}:#{node['project']['user']} /home/#{node['project']['user']}/.gnupg"
  user 'root'
end

chef_rvm 'install rubies' do
  rubies node['ruby']['versions']
  rvmrc(rvm_autoupdate_flag: 1)
  user node['project']['user']
end

chef_rvm_ruby 'set default ruby version' do
  version node['ruby']['default']
  patch 'falcon'
  default true
  user node['project']['user']
end

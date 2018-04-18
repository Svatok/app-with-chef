default['app_name'] = 'site'
default['project']['user'] = 'deployer'
default['project']['root'] = File.join('/home', node['project']['user'], node['app_name'])
default['project']['repository'] = 'git@github.com:Svatok/app-with-chef.gitt'
default['project']['branch'] = 'master'

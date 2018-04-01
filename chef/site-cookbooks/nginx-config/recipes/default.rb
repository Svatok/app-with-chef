include_recipe 'nginx::source'

template "#{node['nginx']['dir']}/sites-available/site" do
  owner 'root'
  group 'root'
  mode '0644'
  variables(
    ip: node[:ipaddress],
    domain: node['project']['domain'],
    project_root: node['project']['root']
  )
  notifies :restart, 'service[nginx]', :delayed
end

nginx_site 'site' do
  enable true
end

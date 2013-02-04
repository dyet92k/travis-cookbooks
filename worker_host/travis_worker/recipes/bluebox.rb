require_recipe 'runit'
require_recipe 'jruby'

users = if Chef::Config[:solo]
          node[:users]
        else
          search(:users)
        end

execute "monit-reload" do
  action :nothing
  command "monit reload"
end

service "travis-worker" do
  action :nothing
end

directory node[:travis][:worker][:home] do
  action :create
  recursive true
  owner "travis"  
  group "travis"
  mode "0755"
end

git node[:travis][:worker][:home] do
  repository node[:travis][:worker][:repository]
  reference node[:travis][:worker][:ref]
  action :sync
  user "travis"
  group "travis"
  notifies :restart, resources(:service => 'travis-worker')
end

directory "#{node[:travis][:worker][:home]}/log" do
  action :create
  owner "travis"  
  group "travis"
  mode "0755"
end

bash "bundle gems" do
  code "#{File.dirname(node[:jruby][:bin])}/bundle install --deployment --binstubs"
  user "travis"
  group "travis"
  cwd node[:travis][:worker][:home]
end

template "#{node[:travis][:worker][:home]}/config/worker.yml" do
  source "worker-bluebox.yml.erb"
  owner "travis"
  group "travis"
  mode "0600"
  variables :amqp => node[:travis][:worker][:amqp],
            :worker => node[:travis][:worker],
            :bluebox => node[:bluebox],
            :librato => node[:collectd_librato]

  notifies :restart, resources(:service => 'travis-worker')
end

runit_service "travis-worker" do
  options :jruby => node[:jruby][:bin],
          :worker_home => node[:travis][:worker][:home],
          :user => "travis",
          :group => "travis"
end

template "/etc/monit/conf.d/travis-worker.monitrc" do
  source "travis-worker.monitrc.erb"
  owner "root"
  group "root"
  mode "0644"
  variables :home => node[:travis][:worker][:home]
  notifies :run, resources(:execute => 'monit-reload')
end
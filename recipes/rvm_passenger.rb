#
# Cookbook Name:: nginx
# Recipe:: RVM Passenger
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

node.default["nginx"]["passenger"]["rvm"]["ruby"] = node["rvm"]["default_ruby"]
node.default["nginx"]["passenger"]["rvm"]["gemset"] = "global"

ruby = node["nginx"]["passenger"]["rvm"]["ruby"]
gemset = node["nginx"]["passenger"]["rvm"]["gemset"]
ruby_string = "#{ruby}@#{gemset}"

node.default["nginx"]["passenger"]["ruby"] = "/usr/local/rvm/wrappers/#{ruby}/ruby"
node.default["nginx"]["passenger"]["root"] = "/usr/local/rvm/gems/#{ruby_string}/gems/passenger-3.0.18"

packages = value_for_platform( ["redhat", "centos", "scientific", "amazon", "oracle"] => {
                                 "default" => %w(ruby-devel curl-devel) },
                               ["ubuntu", "debian"] => {
                                 "default" => %w(ruby-dev libcurl4-gnutls-dev) } )

packages.each do |devpkg|
  package devpkg
end

rvm_gemset gemset do
  ruby_string ruby
end

rvm_gem "passenger" do
  ruby_string ruby_string
  version node["nginx"]["passenger"]["version"]
  action :install
end

rvm_shell "compile passenger support files" do
  ruby_string ruby_string
  user "root"
  code <<-CODE
    cd `passenger-config --root`
    rake nginx RELEASE=yes
  CODE

  creates "#{node["nginx"]["passenger"]["root"]}/ext/common/libpassenger_common.a"
end

template "#{node["nginx"]["dir"]}/conf.d/passenger.conf" do
  source "modules/passenger.conf.erb"
  owner "root"
  group "root"
  mode 00644
  variables(
    :passenger_root => node["nginx"]["passenger"]["root"],
    :passenger_ruby => node["nginx"]["passenger"]["ruby"],
    :passenger_spawn_method => node["nginx"]["passenger"]["spawn_method"],
    :passenger_use_global_queue => node["nginx"]["passenger"]["use_global_queue"],
    :passenger_buffer_response => node["nginx"]["passenger"]["buffer_response"],
    :passenger_max_pool_size => node["nginx"]["passenger"]["max_pool_size"],
    :passenger_min_instances => node["nginx"]["passenger"]["min_instances"],
    :passenger_max_instances_per_app => node["nginx"]["passenger"]["max_instances_per_app"],
    :passenger_pool_idle_time => node["nginx"]["passenger"]["pool_idle_time"],
    :passenger_max_requests => node["nginx"]["passenger"]["max_requests"]
  )
  notifies :reload, "service[nginx]"
end

node.run_state['nginx_configure_flags'] =
  node.run_state['nginx_configure_flags'] | ["--add-module=#{node["nginx"]["passenger"]["root"]}/ext/nginx"]

require 'mina/bundler'
require 'mina/rails'

namespace :puma do
  set :web_server, :puma

  set :puma_role,      -> { fetch(:user) }
  set :puma_env,       -> { fetch(:rails_env, 'production') }
  set :puma_config,    -> { "#{fetch(:shared_path)}/config/puma.rb" }
  set :puma_socket,    -> { "#{fetch(:shared_path)}/tmp/sockets/puma.sock" }
  set :puma_state,     -> { "#{fetch(:shared_path)}/tmp/sockets/puma.state" }
  set :puma_pid,       -> { "#{fetch(:shared_path)}/tmp/pids/puma.pid" }
  set :puma_cmd,       -> { "#{fetch(:bundle_prefix)} puma" }
  set :pumactl_cmd,    -> { "#{fetch(:bundle_prefix)} pumactl" }
  set :pumactl_socket, -> { "#{fetch(:shared_path)}/tmp/sockets/pumactl.sock" }
  set :puma_root_path, -> { fetch(:current_path) }

  desc 'Start puma'
  task :start => :remote_environment do
    puma_port_option = "-p #{fetch(:puma_port)}" if set?(:puma_port)

    comment "Starting Puma..."
    command %[
      if [ -e "#{fetch(:pumactl_socket)}" ]; then
        echo 'Puma is already running!';
      else
        if [ -e "#{fetch(:puma_config)}" ]; then
          cd #{fetch(:puma_root_path)} && #{fetch(:puma_cmd)} -q -d -e #{fetch(:puma_env)} -C #{fetch(:puma_config)}
        else
          cd #{fetch(:puma_root_path)} && #{fetch(:puma_cmd)} -q -d -e #{fetch(:puma_env)} -b "unix://#{fetch(:puma_socket)}" #{puma_port_option} -S #{fetch(:puma_state)} --pidfile #{fetch(:puma_pid)} --control 'unix://#{fetch(:pumactl_socket)}'
        fi
      fi
    ]
  end

  desc 'Stop puma'
  task stop: :remote_environment do
    comment "Stopping Puma..."
    pumactl_command 'stop'
    command %[rm -f '#{fetch(:pumactl_socket)}']
  end

  desc 'Restart puma'
  task restart: :remote_environment do
    comment "Restart Puma...."
    pumactl_command 'restart'
  end

  namespace :restart do
    desc 'Restart puma or start if not running'
    task :or_start => :remote_environment do
      comment "Restart Puma ..."
      pumactl_command 'restart', true
    end
  end

  desc 'Restart puma (phased restart)'
  task phased_restart: :remote_environment do
    comment "Restart Puma -- phased..."
    pumactl_command 'phased-restart'
  end

  namespace :phased_restart do
    desc 'Restart puma (phased restart) or start if not running'
    task :or_start => :remote_environment do
      comment "Restart Puma -- phased..."
      pumactl_command 'phased-restart', true
    end
  end

  desc 'Restart puma (hard restart)'
  task hard_restart: :remote_environment do
    comment "Restart Puma -- hard..."
    invoke 'puma:stop'
    invoke 'puma:start'
  end

  desc 'Get status of puma'
  task status: :remote_environment do
    comment "Puma status..."
    pumactl_command 'status'
  end

  def pumactl_command(command, or_start = false)
    puma_port_option = "-p #{fetch(:puma_port)}" if set?(:puma_port)

    cmd =  %{
      if [ -e "#{fetch(:pumactl_socket)}" ]; then
        if [ -e "#{fetch(:puma_config)}" ]; then
          cd #{fetch(:puma_root_path)} && #{fetch(:pumactl_cmd)} -F #{fetch(:puma_config)} #{command}
        else
          cd #{fetch(:puma_root_path)} && #{fetch(:pumactl_cmd)} -S #{fetch(:puma_state)} -C "unix://#{fetch(:pumactl_socket)}" --pidfile #{fetch(:puma_pid)} #{command}
        fi
      else
        if [[ "#{or_start}" == "true"* ]];then
          echo 'Puma is not running, starting!';
          if [ -e "#{fetch(:puma_config)}" ]; then
            cd #{fetch(:puma_root_path)} && #{fetch(:puma_cmd)} -q -d -e #{fetch(:puma_env)} -C #{fetch(:puma_config)}
          else
            cd #{fetch(:puma_root_path)} && #{fetch(:puma_cmd)} -q -d -e #{fetch(:puma_env)} -b "unix://#{fetch(:puma_socket)}" #{puma_port_option} -S #{fetch(:puma_state)} --pidfile #{fetch(:puma_pid)} --control 'unix://#{fetch(:pumactl_socket)}'
          fi
        fi
      fi
    }
    command cmd
  end
end
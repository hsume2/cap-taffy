require 'rubygems'
begin
  gem 'taps', '>= 0.2.8', '< 0.3.0'
  require 'taps/client_session'
rescue LoadError
  error "Install the Taps gem to use db commands. On most systems this will be:\nsudo gem install taps"
end

require File.join(File.dirname(__FILE__), 'parse')
require 'digest/sha1'

module CapTaffy::Db
  extend self

  def local(env)
    return "" unless File.exists?(Dir.pwd + '/config/database.yml')
    db_config = YAML.load(File.read(Dir.pwd + '/config/database.yml'))

    CapTaffy::Parse.database_url(db_config, env)
  end

  def remote(instance, env)
    db_yml = instance.capture "cat #{instance.current_path}/config/database.yml"
    db_config = YAML::load(db_yml)

    CapTaffy::Parse.database_url(db_config, env)
  end

  def default_server_port
    5000
  end

  def remote_url(options={})
    host = options[:host]
    port = options[:port] || default_server_port
    host += ":#{port}"
    url = CapTaffy::Parse.new.uri_hash_to_url('username' => options[:login], 'password' => options[:password], 'host' => host, 'scheme' => 'http', 'path' => '')

    url.sub(/\/$/, '')
  end

  def tmp_pass(user)
    Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{user}--")
  end

  def taps_client(local_database_url, remote_url, &blk)
    Taps::Config.chunksize = 1000
    Taps::Config.database_url = local_database_url
    Taps::Config.remote_url = remote_url
    Taps::Config.verify_database_url

    Taps::ClientSession.quickstart do |client|
      yield client
    end
  end

  # server <local_database_url> <login> <password> [--port=N]
  def server_command(options={})
    remote_database_url, login, password, port = options[:remote_database_url], options[:login], options[:password], options[:port]
    port_argument = ''
    port_argument = " --port=#{port}" if port && port != default_server_port

    "taps server #{remote_database_url} #{login} #{password}#{port_argument}"
  end

  def run(instance, options = {} , &blk)
    options[:port] ||= default_server_port
    remote_database_url, login, password, port, local_database_url = options[:remote_database_url], options[:login], options[:password], options[:port], options[:local_database_url]
    force_local = options.delete(:local)

    data_so_far = ""
    instance.run CapTaffy::Db.server_command(options) do |channel, stream, data|
      data_so_far << data
      if data_so_far.include? ">> Listening on 0.0.0.0:#{port}, CTRL+C to stop"
        host = force_local ? '127.0.0.1' : channel[:host]
        remote_url = CapTaffy::Db.remote_url(options.merge(:host => host))

        CapTaffy::Db.taps_client(local_database_url, remote_url) do |client|
          yield client
        end

        data_so_far = ""
        channel.close
        channel[:status] = 0
      end
    end
  end

  class InvalidURL < RuntimeError; end
end

Capistrano::Configuration.instance.load do
  namespace :db do
    def dry_run_safe(returning = nil, &block)
      begin
        yield
      rescue Exception => e
        raise e unless dry_run
        return returning
      end
    end

    task :detect, :roles => :app do
      @remote_database_url = dry_run_safe('') { CapTaffy::Db.remote(self, 'production') }
      @local_database_url = dry_run_safe('') { CapTaffy::Db.local('development') }
    end

    desc <<-DESC
      Push a local database into the app's remote database.
      
      Performs push from local development database to remote production database.
      Opens a Taps server on port 5000. (Ensure port is opened on the remote server).
      
        # alternately, specify a different port
        cap db:push -s taps_port=4321
        
      For the security conscious:
      
        # use ssh local forwarding (ensure [port] is available on both endpoints)
        ssh -N -L[port]:127.0.0.1:[port] [user]@[remote-server]
        
        # then push locally
        cap db:push -s taps_port=[port] -s local=true
    DESC
    task :push, :roles => :app do      
      detect

      login = fetch(:user)
      password = CapTaffy::Db.tmp_pass(login)

      logger = Capistrano::Logger.new
      logger.important "Auto-detected remote database: #{@remote_database_url}" if @remote_database_url != ''
      logger.important "Auto-detected local database: #{@local_database_url}" if @local_database_url != ''

      options = {:remote_database_url => @remote_database_url, :login => login, :password => password, :local_database_url => @local_database_url, :port => variables[:taps_port]}
      options.merge!(:local => true) if variables[:local]

      CapTaffy::Db.run(self, options) do |client|
        client.cmd_send
      end
    end

    desc <<-DESC
      Pull the app's database into a local database.
      
      Performs pull from remote production database to local development database.
      Opens a Taps server on port 5000. (Ensure port is opened on the remote server).
        
        # alternately, specify a different port
        cap db:pull -s taps_port=4321
        
      For the security conscious:

        # use ssh local forwarding (ensure [port] is available on both endpoints)
        ssh -N -L[port]:127.0.0.1:[port] [user]@[remote-server]

        # then pull locally
        cap db:pull -s taps_port=[port] -s local=true
    DESC
    task :pull, :roles => :app do
      detect

      login = fetch(:user)
      password = CapTaffy::Db.tmp_pass(login)

      logger = Capistrano::Logger.new
      logger.important "Auto-detected remote database: #{@remote_database_url}" if @remote_database_url != ''
      logger.important "Auto-detected local database: #{@local_database_url}" if @local_database_url != ''

      options = {:remote_database_url => @remote_database_url, :login => login, :password => password, :local_database_url => @local_database_url, :port => variables[:taps_port]}
      options.merge!(:local => true) if variables[:local]

      CapTaffy::Db.run(self, options) do |client|
        client.cmd_receive
      end
    end
  end
end

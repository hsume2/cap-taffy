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

  # Detects the local database url for +env+.
  #
  # Looks for <tt>config/database.yml</tt>.
  def local_database_url(env)
    return "" unless File.exists?(Dir.pwd + '/config/database.yml')
    db_config = YAML.load(File.read(Dir.pwd + '/config/database.yml'))

    CapTaffy::Parse.database_url(db_config, env)
  end

  # Detects the remote database url for +env+ and the current Capistrano +instance+.
  #
  # Looks for <tt>config/database.yml</tt> in the +current_path+.
  def remote_database_url(instance, env)
    db_yml = instance.capture "cat #{instance.current_path}/config/database.yml"
    db_config = YAML::load(db_yml)

    CapTaffy::Parse.database_url(db_config, env)
  end

  # The default server port the Taps server is started on.
  def default_server_port
    5000
  end

  # Generates the remote url used by Taps push/pull.
  #
  # ==== Parameters
  # 
  # * <tt>:login, :password, :host, :port</tt> - See #run.
  #
  # ==== Examples
  #
  #   login = fetch(:user)
  #   password = tmp_pass(login)                                               # returns asdkf239udjhdaks (for example)
  #   remote_url(:login => login, :password => password, :host => 'load-test') # returns http://henry:asdkf239udjhdaks@load-test:5000
  def remote_url(options={})
    host = options[:host]
    port = options[:port] || default_server_port
    host += ":#{port}"
    url = CapTaffy::Parse.new.uri_hash_to_url('username' => options[:login], 'password' => options[:password], 'host' => host, 'scheme' => 'http', 'path' => '')

    url.sub(/\/$/, '')
  end

  # Generates a temporary password to be used for the Taps server command.
  def tmp_pass(user)
    Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{user}--")
  end

  # A quick start for a Taps client.
  #
  # <tt>local_database_url</tt> and <tt>remote_url</tt> refer to the options for the Taps gem (see #run).
  def taps_client(local_database_url, remote_url, &blk) # :yields: client
    Taps::Config.chunksize = 1000
    Taps::Config.database_url = local_database_url
    Taps::Config.remote_url = remote_url
    Taps::Config.verify_database_url

    Taps::ClientSession.quickstart do |client|
      yield client
    end
  end

  # Generates the server command used to start a Taps server
  #
  # ==== Parameters
  # * <tt>:remote_database_url, :login, :password</tt> - See #run.
  # * <tt>:port</tt> - The +port+ the Taps server is on. If given and different from #default_server_port, appends <tt>--port=[port]</tt> to command.
  def server_command(options={})
    remote_database_url, login, password, port = options[:remote_database_url], options[:login], options[:password], options[:port]
    port_argument = ''
    port_argument = " --port=#{port}" if port && port != default_server_port

    "taps server #{remote_database_url} #{login} #{password}#{port_argument}"
  end

  # The meat of the operation. Runs operations after setting up the Taps server.
  # 
  # 1. Runs the <tt>taps</tt> taps command to start the Taps server (assuming Sinatra is running on Thin)
  # 2. Wait until the server is ready 
  # 3. Execute block on Taps client
  # 4. Close the connection(s) and bid farewell.
  #
  # ==== Parameters
  # * <tt>:remote_database_url</tt> - Refers to local database url in the options for the Taps server command (see Taps Options).
  # * <tt>:login</tt> - The login for +host+. Usually what's in <tt>set :user, "the user"</tt> in <tt>deploy.rb</tt>
  # * <tt>:password</tt> - The temporary password for the Taps server.
  # * <tt>:port</tt> - The +port+ the Taps server is on. If not given, defaults to #default_server_port.
  # * <tt>:local_database_url</tt> - Refers to the local database url in the options for Taps client commands (see Taps Options).
  #
  # ==== Taps Options
  #
  # <tt>taps</tt>
  #   server <local_database_url> <login> <password> [--port=N]        Start a taps database import/export server
  #   pull <local_database_url> <remote_url> [--chunksize=N]           Pull a database from a taps server
  #   push <local_database_url> <remote_url> [--chunksize=N]           Push a database to a taps server
  #
  # ==== Examples
  #
  #   task :push do
  #     login = fetch(:user)
  #     password = Time.now.to_s
  #     CapTaffy.Db.run(self, { :login => login, :password => password, :remote_database_url => "sqlite://test_production", :local_database_url => "sqlite://test_development" }) do |client|
  #       client.cmd_send
  #     end
  #   end
  def run(instance, options = {} , &blk) # :yields: client
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

  class InvalidURL < RuntimeError # :nodoc:
  end
end

Capistrano::Configuration.instance.load do
  namespace :db do
    # Executes given block.
    # If this is a dry run, any raised exceptions will be caught and +returning+ is returned.
    # If this is not a dry run, any exceptions will be raised as expected.
    def dry_run_safe(returning = nil, &block) # :yields:
      begin
        yield
      rescue Exception => e
        raise e unless dry_run
        return returning
      end
    end

    task :detect, :roles => :app do
      @remote_database_url = dry_run_safe('') { CapTaffy::Db.remote_database_url(self, 'production') }
      @local_database_url = dry_run_safe('') { CapTaffy::Db.local_database_url('development') }
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

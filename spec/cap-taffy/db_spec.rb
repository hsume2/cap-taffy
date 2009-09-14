require File.join(File.dirname(__FILE__), %w[.. spec_helper])

module CapTaffy
  describe 'Db' do
    context "when loaded" do
      include CapistranoHelpers
      include TaffyHelpers

      before do
        CapTaffy.send(:remove_const, "Db") rescue nil
      end

      it "should load in capistrano configuration instance" do;
        Capistrano::Configuration.instance.expects(:load)

        load 'lib/cap-taffy/db.rb'
      end

      it "should define :db namespace" do
        Capistrano::Configuration.instance.expects(:namespace).with(:db)

        load 'lib/cap-taffy/db.rb'
      end

      for_task :detect, :roles => :app, :it => "should be defined" do
        @db_mod.expects(:remote).returns("remote_db_url")
        @db_mod.expects(:local).returns("local_db_url")
        
        load 'lib/cap-taffy/db.rb'
        
        @namespace_db.instance_variable_get(:@remote_database_url).should == "remote_db_url"
        @namespace_db.instance_variable_get(:@local_database_url).should == "local_db_url"
      end

      for_task :push, :roles => :app, :it => "should send taps client cmd_send" do
        options = {:remote_database_url => "remote", :local_database_url => "local", :port => nil, :login => "a_user", :password => "a_pass"}
        @namespace_db.expects(:detect)
        namespace_with_variables(:taps_port => nil)
        namespace_with_expected_options(options)

        @db_mod.expects(:tmp_pass).with(@namespace_db.fetch(:user)).returns(options[:password])
        @db_mod.expects(:run).with(@namespace_db, options).yields(taps_client_who(:expects, :cmd_send))

        load_taffy
      end

      for_task :push, :roles => :app, :it => "should use cli argument for port" do
        options = {:remote_database_url => "remote", :local_database_url => "local", :port => 1234, :login => "a_user", :password => "a_pass"}
        @namespace_db.expects(:detect)
        namespace_with_variables(:taps_port => 1234)
        namespace_with_expected_options(options)
        @db_mod.expects(:tmp_pass).with(@namespace_db.fetch(:user)).returns(options[:password])
        @db_mod.expects(:run).with(@namespace_db, options)

        load_taffy
      end

      for_task :push, :roles => :app, :it => "should force 127.0.0.1 (local) for ssh local forwarding" do
        options = {:remote_database_url => "remote", :local_database_url => "local", :port => 1234, :login => "a_user", :password => "a_pass"}
        @namespace_db.expects(:detect)
        namespace_with_variables(:taps_port => 1234, :local => true)
        namespace_with_expected_options(options)
        @db_mod.expects(:tmp_pass).with(@namespace_db.fetch(:user)).returns(options[:password])
        @db_mod.expects(:run).with(@namespace_db, options.merge(:local => true))

        load_taffy
      end
      
      for_task :pull, :roles => :app, :it => "should send taps client cmd_receive" do
        options = {:remote_database_url => "remote", :local_database_url => "local", :port => nil, :login => "a_user", :password => "a_pass"}
        @namespace_db.expects(:detect)
        namespace_with_variables(:taps_port => nil)
        namespace_with_expected_options(options)

        @db_mod.expects(:tmp_pass).with(@namespace_db.fetch(:user)).returns(options[:password])
        @db_mod.expects(:run).with(@namespace_db, options).yields(taps_client_who(:expects, :cmd_receive))

        load_taffy
      end
    end

    context "after capistrano" do
      include TaffyHelpers

      before do
        Capistrano::Configuration.instance.expects(:namespace).with(:db)
        CapTaffy.send(:remove_const, "Db") rescue nil
        load 'lib/cap-taffy/db.rb'

        @conf = {"test"=>
          {"reconnect"=>false,
          "encoding"=>"utf8",
          "username"=>"root",
          "adapter"=>"postgresql",
          "database"=>"test_test",
          "pool"=>5,
          "password"=>"root",
          "host"=>"localhost"}}

        @options = {:remote_database_url => "remote", :local_database_url => "local", :port => nil, :login => "a_user", :password => "a_pass"}
      end

      it "should detect local database url" do
        File.expects(:exists?).returns(true)
        File.expects(:read).returns(mock())
        YAML.expects(:load).returns(@conf)
        env = 'test'
        Parse.expects(:database_url).with(@conf, env)

        Db.local(env)
      end

      it "should detect remote database url" do
        instance = mock()
        instance.stubs(:current_path).returns("/home/user/public_html/current")
        instance.expects(:capture).with("cat /home/user/public_html/current/config/database.yml")
        YAML.expects(:load).returns(@conf)
        env = 'test'
        Parse.expects(:database_url).with(@conf, env)

        Db.remote(instance, env)
      end

      it "should create temporary password from time and user" do
        Time.stubs(:now).returns("asdfasdfasdf")
        user = "me"
        tmp_pass = Digest::SHA1.hexdigest("--#{Time.now.to_s}--#{user}--")

        Db.tmp_pass(user).should == tmp_pass
      end

      it "should expose a basic taps client" do
        client = mock()
        local_database_url = mock()
        remote_url = mock()
        Taps::Config.expects(:chunksize=).with(1000)
        Taps::Config.expects(:database_url=).with(local_database_url)
        Taps::Config.expects(:remote_url=).with(remote_url)
        Taps::Config.expects(:verify_database_url)
        client.expects(:do_something)

        Taps::ClientSession.expects(:quickstart).yields(client)

        Db.taps_client(local_database_url, remote_url) do |client|
          client.do_something
        end
      end

      it "should define default port" do
        Db.default_server_port.should == 5000
      end

      it "should build server command" do
        remote_database_url, login, password, port = @options[:remote_database_url], @options[:login], @options[:password], @options[:port]

        Db.server_command(@options).should == "taps server #{remote_database_url} #{login} #{password}"
      end
      
      it "should build server command with port" do
        @options[:port] = 1234
        remote_database_url, login, password, port = @options[:remote_database_url], @options[:login], @options[:password], @options[:port]

        Db.server_command(@options).should == "taps server #{remote_database_url} #{login} #{password} --port=#{port}"
      end
      
      it "should build server command without port if same as default port" do
        @options[:port] = 5000
        remote_database_url, login, password = @options[:remote_database_url], @options[:login], @options[:password]

        Db.server_command(@options).should == "taps server #{remote_database_url} #{login} #{password}"
      end

      def parser_expects_uri_hash_to_url_with(login, password, host)
        parser = mock()
        Parse.expects(:new).at_least_once.returns(parser)
        parser.expects(:uri_hash_to_url).
          with('username' => login, 'password' => password, 'host' => host, 'scheme' => 'http', 'path' => '').returns("remote_url")
      end

      it "should build remote url (with some help)" do
        @options[:host] = "127.0.0.1"        
        parser_expects_uri_hash_to_url_with(@options[:login], @options[:password], "#{@options[:host]}:#{Db.default_server_port}")

        Db.remote_url(@options)
      end

      it "should build remote url with different port" do
        @options[:host] = "127.0.0.1"
        @options[:port] = 1234
        parser_expects_uri_hash_to_url_with(@options[:login], @options[:password], "#{@options[:host]}:#{@options[:port]}")

        Db.remote_url(@options)
      end

      it "should remove trailing slash from remote url" do
        @options[:host] = "127.0.0.1"
        parser_expects_uri_hash_to_url_with(@options[:login], @options[:password], "#{@options[:host]}:#{Db.default_server_port}").returns("remote_url/")

        Db.remote_url(@options).should == "remote_url"
      end

      running_taffy_it "should run with capistrano" do
        run_capistrano_with(Db.server_command(@options))

        Db.run(@capistrano, @options)
      end

      running_taffy_it "should do something to taps client" do
        channel, stream, data = simulating_run_loop_with :data => ">> Listening on 0.0.0.0:5000, CTRL+C to stop\r\n" do
          run_capistrano_with(Db.server_command(@options))
        end
        channel.expects(:close)

        Db.expects(:remote_url).with(@options.merge(:host => channel[:host], :port => 5000)).returns("remote_url")
        Db.expects(:taps_client).with("local", "remote_url").yields(taps_client_who(:expects, :do_something))
        Db.run(@capistrano, @options) do |client|
          client.do_something
        end

        channel[:status].should == 0
      end

      running_taffy_it "should run taffy on different port" do
        @options[:port] = 1234

        channel, stream, data = simulating_run_loop_with :data => ">> Listening on 0.0.0.0:1234, CTRL+C to stop\r\n" do
          run_capistrano_with(Db.server_command(@options))
        end
        channel.expects(:close)
        Db.expects(:remote_url).with(@options.merge(:host => channel[:host])).returns("remote_url")
        Db.expects(:taps_client).with("local", "remote_url").yields(taps_client_who(:expects, :do_something))

        Db.run(@capistrano, @options) do |client|
          client.do_something
        end

        channel[:status].should == 0
      end

      running_taffy_it "should not do anything until taps sinatra server is running" do
        simulating_run_loop_with :data => "asdfasdf" do
          run_capistrano_with(Db.server_command(@options))
        end

        client = mock()
        client.expects(:do_something).never

        Db.run(@capistrano, @options) do |client|
          client.do_something
        end

        channel, stream, data = simulating_run_loop_with :data => ">> Listening on 0.0.0.0:5000, CTRL+C to stop\r\n" do
          run_capistrano_with(Db.server_command(@options))
        end
        channel.expects(:close)
        Db.expects(:remote_url).with(@options.merge(:host => channel[:host], :port => 5000)).returns("remote_url")
        Db.expects(:taps_client).with("local", "remote_url").yields(taps_client_who(:expects, :do_something))

        Db.run(@capistrano, @options) do |client|
          client.do_something
        end

        channel[:status].should == 0
      end

      running_taffy_it "should force 127.0.0.1 (local) for remote url" do
        channel, stream, data = simulating_run_loop_with :data => ">> Listening on 0.0.0.0:5000, CTRL+C to stop\r\n" do
          run_capistrano_with(Db.server_command(@options))
        end
        channel.expects(:close)

        Db.expects(:remote_url).with(@options.merge(:host => '127.0.0.1', :port => 5000)).returns("remote_url")
        Db.expects(:taps_client).with("local", "remote_url").yields(taps_client_who(:expects, :do_something))
        Db.run(@capistrano, @options.merge(:local => true)) do |client|
          client.do_something
        end

        channel[:status].should == 0
      end
    end
  end
end

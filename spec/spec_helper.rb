require File.expand_path(File.join(File.dirname(__FILE__), %w[.. lib cap-taffy]))

module Capistrano
end

Spec::Runner.configure do |config|
  # == Mock Framework
  #
  # RSpec uses it's own mocking framework by default. If you prefer to
  # use mocha, flexmock or RR, uncomment the appropriate line:
  #
  config.mock_with :mocha
  # config.mock_with :flexmock
  # config.mock_with :rr
end

Capistrano.send(:remove_const, "Configuration") rescue nil
Capistrano.const_set("Configuration", Class.new)
Capistrano::Configuration.class_eval do
  def self.instance
    @instance ||= Capistrano::Configuration.new
  end

  def load(*args, &block)
    instance_eval(&block) if block_given?
  end

  def namespaces
    @namespaces ||= {}
  end

  def namespace(name, &block)
    namespaces[name].instance_eval(&block)
  end
end

module CapistranoHelpers
  def self.included(base)
    base.extend CapistranoHelpers::ClassMethods
  end

  def with_logger(&blk)
    logger_class = Class.new
    logger = mock()
    logger.stub_everything
    logger_class.stubs(:new).returns(logger)
    Capistrano.const_set("Logger", logger_class)
    yield
  ensure
    Capistrano.send(:remove_const, "Logger") rescue nil
  end

  def load_taffy
    with_logger do
      load 'lib/cap-taffy/db.rb'
    end
  end

  def namespace_with_expected_options(options)
    @namespace_db.stubs(:fetch).with(:user).returns(options[:login])
    @namespace_db.instance_variable_set(:@remote_database_url, options[:remote_database_url])
    @namespace_db.instance_variable_set(:@local_database_url, options[:local_database_url])
  end

  def namespace_with_variables(variables)
    @namespace_db.stubs(:variables).returns(variables)
  end


  module ClassMethods
    def for_task(task_name, options = {}, &block)
      message = options.delete(:it)
      context ":#{task_name.to_s} task" do
        before do
          @namespace_db = Capistrano::Configuration.instance.namespaces[:db] = mock()
          @namespace_db.stubs(:desc)
          @namespace_db.stubs(:task)
          @namespace_db.expects(:task).with(task_name, options).yields

          @db_mod = Module.new
          CapTaffy.const_set("Db", @db_mod)
        end

        it message, &block

        after do
          CapTaffy.send(:remove_const, "Db")
        end
      end
    end
  end
end

module TaffyHelpers
  def self.included(base)
    base.extend TaffyHelpers::ClassMethods
  end

  def taps_client_who(method_symbol, *args)
    client = mock()
    client.send(method_symbol, *args)
    client
  end

  module ClassMethods
    def running_taffy_it(message, &blk)
      context "when running taffy" do
        before do
          @capistrano = mock()
        end

        def run_capistrano_with(*args)
          @capistrano.expects(:run).with(*args)
        end

        # invokes one loop of block, passing in channel, stream, data as arguments
        def simulating_run_loop_with(options={}, &blk)
          channel = options[:channel] || {:host => "192.168.1.20"}
          stream = options[:stream]
          data = options[:data]

          blk.call.then.yields(channel, stream, data)
          [channel, stream, data]
        end

        it message, &blk

        after do

        end
      end
    end
  end
end

require File.expand_path(File.join(File.dirname(__FILE__), %w[.. lib cap-taffy]))

module Capistrano # :nodoc:
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

class String # :nodoc:
  def demodulize
    gsub(/^.*::/, '')
  end
end

module CapistranoHelpers
  def self.included(base) # :nodoc:
    base.extend CapistranoHelpers::ClassMethods
  end

  # Stubs the Capistrano Logger and yields to the block
  def with_logger(&blk) # :yields:
    logger_class = Class.new
    logger = mock()
    logger.stub_everything
    logger_class.stubs(:new).returns(logger)
    Capistrano.const_set("Logger", logger_class)
    yield
  ensure
    Capistrano.send(:remove_const, "Logger") rescue nil
  end

  # Helper for common operations in db tasks
  def db_with_expected_options(options) # :nodoc:
    @namespace.stubs(:fetch).with(:user).returns(options[:login])
    @namespace.instance_variable_set(:@remote_database_url, options[:remote_database_url])
    @namespace.instance_variable_set(:@local_database_url, options[:local_database_url])
  end

  # Stubs the variables hash used by Capistrano to accept command-line parameters
  def namespace_with_variables(variables) # :nodoc:
    @namespace.stubs(:variables).returns(variables)
  end

  # Creates an expectation for the Capistrano namespace/task <tt>instance</tt> for the <tt>:run</tt> action with <tt>*args</tt>.
  def run_with(instance, *args)
    instance.expects(:run).with(*args)
  end

  # The Capistrano <tt>:run</tt> action loops with <tt>channel</tt>, <tt>stream</tt>, and <tt>data</tt> until the channel is closed.
  # 
  # Passing in a <tt>:run</tt> expectation, modifies the expectation such that each subsequent invocation ("loop") yields <tt>channel</tt>, <tt>stream</tt>, and <tt>data</tt>
  #
  # ==== Parameters
  #
  # * <tt>:channel</tt> - A hash containing <tt>:host</tt>.
  # * <tt>:stream</tt> - A stream object.
  # * <tt>:data</tt> - A data object, usually a String.
  def simulating_run_loop_with(options={}, &blk) # :yields:
    channel = options[:channel] || {:host => "192.168.1.20"}
    stream = options[:stream]
    data = options[:data]

    blk.call.then.yields(channel, stream, data)
    [channel, stream, data]
  end

  module ClassMethods
    # Used in specs to test Capistrano tasks.
    #
    # 
    # Code defined in the task will be executed automatically on load. (Note the <tt>yields</tt>, see Mocha#yields[http://mocha.rubyforge.org/classes/Mocha/Expectation.html#M000043])
    #
    # ==== Parameters
    #
    # * <tt>:it</tt> - The description for the current example group.
    # * <tt>:in</tt> - Specifies the module under test (as well as the namespace the task is defined in). The namespace will be deduced with the downcase of <tt>:in</tt>
    #
    # ==== Examples
    #
    #   for_task :detect, :roles => :app, :in => :Somewhere, :it => "should so something" do
    #     @namespace # refers to the current task under test (in Capistrano tasks are executed on Capistrano::Namespaces::Namespace instances)
    #     @mod       # refers to module CapTaffy::Somewhere
    #   end
    def for_task(task_name, options, &block)
      description = options.delete(:it)
      namespace = options.delete(:in)

      context ":#{task_name.to_s} task" do
        before do
          @namespace = Capistrano::Configuration.instance.namespaces[namespace.to_s.downcase.to_sym] = mock()
          @namespace.stubs(:desc)
          @namespace.stubs(:task)
          args = [task_name, options]
          unless options.empty?
            @namespace.expects(:task).with(*args).yields
          else
            @namespace.expects(:task).with(task_name).yields
          end

          @mod = Module.new # The module under test
          CapTaffy.const_set(namespace, @mod)
        end

        it description, &block

        after do
          const_name = @mod.to_s.demodulize
          CapTaffy.send(:remove_const, const_name)
        end
      end
    end
  end
end

module TaffyHelpers
  def self.included(base) # :nodoc:
    base.extend TaffyHelpers::ClassMethods
  end

  # A simple helper for mocking a quick object
  # 
  # Usage:
  #   taps_client_who(:expects, :do_something)
  def taps_client_who(method_symbol, *args)
    client = mock()
    client.send(method_symbol, *args)
    client
  end

  module ClassMethods
    # A wrapper for running CapTaffy::Db::run
    def running_db_it(message, &blk)
      context "when running db" do
        before do
          @capistrano = mock()
        end

        # See CapistranoHelpers
        def capistrano_run_with(*args)
          run_with(@capistrano, *args) 
        end

        it message, &blk

        after do

        end
      end
    end
  end
end

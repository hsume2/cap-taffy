require 'rubygems'
begin
  require 'heroku'
  require 'heroku/commands/base'
  require 'heroku/commands/db'
rescue LoadError
  error "Install the Heroku gem. On most systems this will be:\nsudo gem install taps"
end

module CapTaffy
  class Parse < Heroku::Command::Db
    class << self
      attr_accessor :instance

      # Modified from :parse_database_yml in heroku/command/db.rb
      def database_url(db_config, env)
        raise Invalid, "please pass me a valid Hash loaded from a database YAML file" unless db_config
        conf = db_config[env]
        raise Invalid, "missing '#{env}' database in #{db_config.inspect}" unless conf

        self.instance ||= CapTaffy::Parse.new

        case conf['adapter']
        when 'sqlite3'
          return "sqlite://#{conf['database']}"
        when 'postgresql'
          uri_hash = self.instance.conf_to_uri_hash(conf)
          uri_hash['scheme'] = 'postgres'
          return self.instance.uri_hash_to_url(uri_hash)
        else
          return self.instance.uri_hash_to_url(self.instance.conf_to_uri_hash(conf))
        end
      end
    end

    def initialize

    end

    # Do nothing
    def escape(string)
      string
    end

    public :uri_hash_to_url, :conf_to_uri_hash

    class Invalid < RuntimeError; end
  end
end

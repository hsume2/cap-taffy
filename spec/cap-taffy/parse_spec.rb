require File.join(File.dirname(__FILE__), %w[.. spec_helper])
require 'lib/cap-taffy/parse'

module CapTaffy
  describe Parse do
    before do
      @database_config = {"production"=>
                          {"reconnect"=>false,
                           "encoding"=>"utf8",
                           "username"=>"root",
                           "adapter"=>"mysql",
                           "database"=>"test_production",
                           "pool"=>5,
                           "password"=>"root",
                           "host"=>"localhost"},
                         "development"=>
                          {"username"=>"root",
                           "adapter"=>"sqlite3",
                           "database"=>"test_development",
                           "password"=>"root"},
                         "test"=>
                          {"reconnect"=>false,
                           "encoding"=>"utf8",
                           "username"=>"root",
                           "adapter"=>"postgresql",
                           "database"=>"test_test",
                           "pool"=>5,
                           "password"=>"root",
                           "host"=>"localhost"}}
    end

    it "should do pass-through for escape" do
      Parse.new.escape("something").should == "something"
    end

    it "should parse database config for sqlite" do
      Parse.expects(:conf_to_uri_hash).never
      Parse.database_url(@database_config, 'development').should == "sqlite://test_development"
    end

    it "should parse database config for postgresql" do
      Parse.database_url(@database_config, 'test').should == "postgres://root:root@localhost/test_test?encoding=utf8"
    end

    it "should parse database config for mysql" do
      Parse.database_url(@database_config, 'production').should == "mysql://root:root@localhost/test_production?encoding=utf8"
    end
    
    it "should raise invalid conf if so" do
      lambda { Parse.database_url(nil, nil) }.should raise_error(Parse::Invalid)
    end

    it "should raise invalid conf if so" do
      lambda { Parse.database_url(@database_config, nil) }.should raise_error(Parse::Invalid)
    end
  end
end

require File.join(File.dirname(__FILE__), %w[.. spec_helper])

module CapTaffy
  describe 'SSH' do
    include CapistranoHelpers

    before do
      CapTaffy.send(:remove_const, "SSH") rescue nil
    end

    it "should load in capistrano configuration instance" do;
      Capistrano::Configuration.instance.expects(:load)

      load 'lib/cap-taffy/ssh.rb'
    end

    it "should define :db namespace" do
      Capistrano::Configuration.instance.expects(:namespace).with(:ssh)

      load 'lib/cap-taffy/ssh.rb'
    end

    for_task :authorize, :in => :SSH, :it => "should capture the authorized_keys" do
      @namespace.expects(:capture).with("cat ~/.ssh/authorized_keys")
      load 'lib/cap-taffy/ssh.rb'
    end
  end
end

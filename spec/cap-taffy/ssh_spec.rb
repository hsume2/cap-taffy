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

    def simulating_line(line, &blk)
      blk.call.then.yields(line)
      line
    end

    for_task :authorize, :in => :SSH, :it => "should authorize on each server" do
      public_key = "ssh-key2\n"
      File.expects(:read).with(File.expand_path(File.join(%w[~/ .ssh id_rsa.pub]))).returns(public_key)

      run_with(@namespace, anything) # Don't rly wna test bash scripts

      load 'lib/cap-taffy/ssh.rb'
    end
  end
end

require File.join(File.dirname(__FILE__), %w[.. cap-taffy]) unless defined?(CapTaffy)

module CapTaffy::SSH

end

Capistrano::Configuration.instance.load do
  namespace :ssh do
    desc <<-DESC
      Authorize SSH access for local computer on remote computers(s).
    DESC
    task :authorize do
      public_key = File.read(File.expand_path(File.join(%w[~/ .ssh id_rsa.pub]))).chop

      run %Q[if [ ! -f ~/.ssh/authorized_keys ]; then mkdir -p ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys; fi && if [ -z "$(grep "^#{public_key}$" ~/.ssh/authorized_keys)" ]; then echo "#{public_key}" >> ~/.ssh/authorized_keys && echo "Public key on '$CAPISTRANO:HOST$' authorized at '#{Time.now.to_s}'"; else echo "Public key on '$CAPISTRANO:HOST$' is already authorized."; fi]
    end
  end
end

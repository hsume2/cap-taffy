module CapTaffy::SSH

end

Capistrano::Configuration.instance.load do
  namespace :ssh do
    task :authorize do
      capture "cat ~/.ssh/authorized_keys"
    end
  end
end

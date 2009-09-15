# Look in the tasks/setup.rb file for the various options that can be
# configured in this Rakefile. The .rake files in the tasks directory
# are where the options are used.

begin
  require 'bones'
  Bones.setup
rescue LoadError
  begin
    load 'tasks/setup.rb'
  rescue LoadError
    raise RuntimeError, '### please install the "bones" gem ###'
  end
end

ensure_in_path 'lib'
require 'cap-taffy'

task :default => 'spec:run'

PROJ.name = 'cap-taffy'
PROJ.authors = 'Henry Hsu'
PROJ.email = 'henry@qlane.com'
PROJ.url = 'http://by.qlane.com'
PROJ.version = CapTaffy::VERSION
PROJ.rubyforge.name = 'cap-taffy'
PROJ.readme_file = "README.md"
PROJ.gem.dependencies = ['heroku', 'taps', 'capistrano']
PROJ.gem.development_dependencies << ["mocha"]
PROJ.description = "Capistrano recipes for deploying databases and other common tasks."
PROJ.summary = "Capistrano recipes for deploying databases (managing database.yml, importing/exporting/transfering databases, etc.)"
PROJ.ignore_file = '.gitignore'
PROJ.spec.opts << '--color'
PROJ.exclude << "bin"

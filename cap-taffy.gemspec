# -*- encoding: utf-8 -*-

Gem::Specification.new do |s|
  s.name = %q{cap-taffy}
  s.version = "1.0.0"

  s.required_rubygems_version = Gem::Requirement.new(">= 0") if s.respond_to? :required_rubygems_version=
  s.authors = ["Henry Hsu"]
  s.date = %q{2009-09-14}
  s.description = %q{Capistrano recipes for deploying databases and other common tasks.}
  s.email = %q{henry@qlane.com}
  s.extra_rdoc_files = ["History.txt"]
  s.files = ["History.txt", "README.md", "Rakefile", "cap-taffy.gemspec", "lib/cap-taffy.rb", "lib/cap-taffy/db.rb", "lib/cap-taffy/parse.rb", "lib/cap-taffy/ssh.rb", "spec/cap-taffy/db_spec.rb", "spec/cap-taffy/parse_spec.rb", "spec/cap-taffy/ssh_spec.rb", "spec/cap-taffy_spec.rb", "spec/spec.opts", "spec/spec_helper.rb"]
  s.homepage = %q{http://by.qlane.com}
  s.rdoc_options = ["--main", "README.md"]
  s.require_paths = ["lib"]
  s.rubyforge_project = %q{cap-taffy}
  s.rubygems_version = %q{1.3.5}
  s.summary = %q{Capistrano recipes for deploying databases (managing database.yml, importing/exporting/transfering databases, etc.)}

  if s.respond_to? :specification_version then
    current_version = Gem::Specification::CURRENT_SPECIFICATION_VERSION
    s.specification_version = 3

    if Gem::Version.new(Gem::RubyGemsVersion) >= Gem::Version.new('1.2.0') then
      s.add_runtime_dependency(%q<heroku>, [">= 0"])
      s.add_runtime_dependency(%q<taps>, [">= 0"])
      s.add_runtime_dependency(%q<capistrano>, [">= 0"])
      s.add_development_dependency(%q<bones>, [">= 2.5.1"])
      s.add_development_dependency(%q<mocha>, [">= 0"])
    else
      s.add_dependency(%q<heroku>, [">= 0"])
      s.add_dependency(%q<taps>, [">= 0"])
      s.add_dependency(%q<capistrano>, [">= 0"])
      s.add_dependency(%q<bones>, [">= 2.5.1"])
      s.add_dependency(%q<mocha>, [">= 0"])
    end
  else
    s.add_dependency(%q<heroku>, [">= 0"])
    s.add_dependency(%q<taps>, [">= 0"])
    s.add_dependency(%q<capistrano>, [">= 0"])
    s.add_dependency(%q<bones>, [">= 2.5.1"])
    s.add_dependency(%q<mocha>, [">= 0"])
  end
end

# -*- encoding: utf-8 -*-

Gem::Specification.new do |gem|
  gem.name          = "hiera-mysql-json-backend-jruby"
  gem.version       = "2.2.0"
  gem.authors       = ["Hostnet"]
  gem.email         = ["opensource@hostnet.nl"]
  gem.description   = %q{Alternative MySQL backend with json support for hiera}
  gem.summary       = %q{Alternative MySQL backend with json support for hiera}
  gem.homepage      = "https://github.com/hostnet/hiera-mysql-json-backend"
  gem.license       = "MIT"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.add_dependency('jdbc-mysql')
  gem.add_development_dependency('rake')
end

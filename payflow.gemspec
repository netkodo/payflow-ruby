# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'payflow/version'

Gem::Specification.new do |gem|
  gem.name          = "payflow"
  gem.version       = Payflow::VERSION
  gem.authors       = ["Jonathan Spies", "Ben Bean"]
  gem.email         = ["jonathan.spies@gmail.com"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{TODO: Write a gem summary}
  gem.homepage      = ""

  gem.add_dependency "activemodel", "3.2.13"
  gem.add_dependency "nokogiri", "1.5.9"
  gem.add_dependency "builder", "3.0.0"
  gem.add_dependency "faraday", "0.8.7"

  gem.files         = `git ls-files`.split($/)
  gem.executables   = gem.files.grep(%r{^bin/}).map{ |f| File.basename(f) }
  gem.test_files    = gem.files.grep(%r{^(test|spec|features)/})
  gem.require_paths = ["lib"]
  gem.add_development_dependency "rspec"
  #gem.add_development_dependency "rails", "3.2.13"
end

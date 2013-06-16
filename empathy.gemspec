# -*- encoding: utf-8 -*-
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'empathy/version'

Gem::Specification.new do |gem|
  gem.name          = "empathy"
  gem.version       = Empathy::VERSION
  gem.authors       = ["Grant Gardner","Christopher J. Bottaro"]
  gem.email         = ["grant@lastweekend.com.au"]
  gem.description   = %q{Empathic Eventmachine}
  gem.summary       = %q{Make EventMachine behave like ruby}
  gem.homepage      = "http://rubygems.org/gems/empathy"
  gem.files         = `git ls-files`.split($/)
  gem.test_files    = `git ls-files -- {spec,rubyspec}/*`.split($/)
  gem.require_paths = ["lib"]
  gem.licenses      = %q{MIT}

  gem.has_rdoc      = :yard

  # Empathy can be used without eventmachine
  gem.add_development_dependency 'eventmachine', '~> 1.0.0'

  gem.add_development_dependency 'mspec', '>= 1.5.18'
  gem.add_development_dependency 'rspec'
  gem.add_development_dependency 'rr'
  gem.add_development_dependency 'yard'
  gem.add_development_dependency 'redcarpet'
end

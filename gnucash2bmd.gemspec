lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'gnucash2bmd/version'

Gem::Specification.new do |spec|
  spec.name        = "gnucash2bmd"
  spec.version     = Gnucash2Bmd::VERSION
  spec.author      = "Niklaus Giger"
  spec.email       = "niklaus.giger@member.fsf.org"
  spec.description = "gnucash2bmd converts GnuCash CSV file for BMD.com"
  spec.summary     = "gnucash2bmd BMD.com-csv files."
  spec.homepage    = "https://github.com/ngiger/gnucash2bmd"
  spec.license       = "GPL-3.0"
  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency 'trollop'
  spec.add_dependency 'gnucash'

  spec.add_development_dependency "bundler"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "rspec"
end


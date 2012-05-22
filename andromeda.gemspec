# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'andromeda/version'

Gem::Specification.new do |s|
  s.name        = 'andromeda'
  s.version     = Andromeda::VERSION
  s.summary     = 'light weight framework for complex event processing based on a dataflow DSL'
  s.description = 'Andromeda is a light weight framework for complex event processing on multicore architectures. Andromeda users construct networks of plans that are interconnected via endpoint spots, describe how plans are scheduled onto threads, and process data by feeding data events to the resulting structure.'
  s.author      = 'Stefan Plantikow'
  s.email       = 'stefanp@moviepilot.com'
  s.homepage    = 'https://github.com/moviepilot/andromeda'
  s.rubyforge_project = 'andromeda'

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib"]

  s.bindir      = 'script'
  s.executables = `git ls-files -- script/*`.split("\n").map{ |f| File.basename(f) }
  s.licenses = ['PUBLIC DOMAIN WITHOUT ANY WARRANTY']

  s.add_dependency 'json'
  s.add_dependency 'atomic'
  s.add_dependency 'facter'
  s.add_dependency 'statval'
  s.add_dependency 'threadpool'

  s.add_development_dependency 'rspec'
  s.add_development_dependency 'simplecov'
  s.add_development_dependency 'rake'
  s.add_development_dependency 'yard'

  case RUBY_ENGINE.to_sym
    when :jruby then s.add_development_dependency 'maruku'
    else s.add_development_dependency 'redcarpet'
  end
end

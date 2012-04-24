# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require 'andromeda/version'

Gem::Specification.new do |s|
  s.name        = 'andromeda'
  s.version     = Andromeda::VERSION
  s.summary     = 'Ultra light weight multicore stream processing framework based on a dataflow DSL'
  s.description = s.summary
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
end

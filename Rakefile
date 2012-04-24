require 'bundler/gem_tasks'

require 'rspec'
require 'rspec/core/rake_task'

require 'yard'
require 'yard/rake/yardoc_task'

desc 'Run all rspecs'
RSpec::Core::RakeTask.new(:spec) do |spec|
  spec.fail_on_error = true
  spec.verbose       = false
#  spec.rspec_opts    = ['--backtrace']
end

desc 'Run yardoc over project sources'
YARD::Rake::YardocTask.new(:ydoc) do |t|
  t.options = ['--verbose']	
  t.files   = ['lib/**/*.rb', '-', 'README.md', 'AUTHORS', 'LICENSE.txt']
end

#RDoc::Task.new(:rdoc) do |rdoc|
#  # rdoc.main = "README.rdoc"
#  rdoc.rdoc_files.include("lib/**/*.rb")
#end

desc 'Run irb in project environment'
task :console do
  require 'irb'
  ARGV.clear
  IRB.conf[:USE_READLINE] = false if ENV['JRUBY_OPTS'] =~ /--ng/
  IRB.start
end

task :doc => :ydoc
task :docs => :ydoc
task :test => :spec
task :tests => :spec
task :irb => :console

require 'rubygems'

require 'set'
require 'json'
require 'logger'
require 'threadpool'
require 'facter'
require 'thread'
Facter.loadfacts

require 'andromeda/version'

module Andromeda

	def self.files
		f = []
		f << 'andromeda/id'
		f << 'andromeda/pools'
		f << 'andromeda/scope'
		f << 'andromeda/class_attr'
		f << 'andromeda/dest'
		f << 'andromeda/stage'
		f << 'andromeda/helpers'
		f << 'andromeda/sync'
		f << 'andromeda/command'
		f
	end

	def self.load_relative(f)
		path = "#{File.join(File.dirname(caller[0]), f)}.rb"
 	  load path 
	end

	def self.reload!
		files.each { |f| load_relative f }
	end

end

Andromeda.files.each { |f| require f }


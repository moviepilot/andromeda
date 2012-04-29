require 'rubygems'

require 'set'
require 'singleton'
require 'delegate'
require 'logger'
require 'json'
require 'thread'
require 'threadpool'
require 'facter'
Facter.loadfacts

require 'andromeda/version'

module Andromeda

	def self.files
		f = []
		f << 'andromeda/id'
		f << 'andromeda/error'
		f << 'andromeda/region'
		f << 'andromeda/copy_clone'
		f << 'andromeda/class_attr'
		f << 'andromeda/guide_track'
		# f << 'andromeda/pool_guide'
		f << 'andromeda/spot'
		# f << 'andromeda/plan'
		f << 'andromeda/sugar'
		# f << 'andromeda/kit'
		# f << 'andromeda/command'
		# f << 'andromeda/map_reduce'
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


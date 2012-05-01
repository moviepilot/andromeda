require 'rubygems'

require 'set'
require 'json'
require 'logger'
require 'delegate'
require 'singleton'

require 'atomic'
require 'thread'
require 'facter'
require 'threadpool'
Facter.loadfacts

require 'andromeda/version'

module Andromeda

	def self.files
		f = []
		f << 'andromeda/impl/to_s'
		f << 'andromeda/impl/atom'
		f << 'andromeda/impl/xor_id'
		f << 'andromeda/impl/class_attr'
		f << 'andromeda/impl/proto_plan'

		f << 'andromeda/id'
		f << 'andromeda/atom'
		f << 'andromeda/error'
		f << 'andromeda/copy_clone'
		f << 'andromeda/guide_track'
		f << 'andromeda/pool_guide'

		f << 'andromeda/spot'
		f << 'andromeda/plan'
		f << 'andromeda/sync'
		f << 'andromeda/sugar'

		f << 'andromeda/kit'
		f << 'andromeda/cmd'
		f << 'andromeda/map_reduce'
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


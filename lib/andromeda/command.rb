module Andromeda

	class Command
		attr_reader :cmd
		attr_reader :data
		attr_reader :time

		def initialize(cmd, data = {}, cmd_time = nil)
			raise ArgumentError unless cmd.kind_of?(Symbol)
			@cmd     = cmd
			@data    = data
			@time    = if cmd_time then cmd_time else Time.now.to_i end			
			@comment = nil
		end

		def comment ; @comment || ''  end
		def comment=(str = nil) ;	@comment = str end

		def if_cmd(sym) ; if sym == cmd then yield data else seld end end

		def as_json
			h = { cmd: cmd, data: (data.as_json rescue data), time: time } 
			c = @comment
			h[:comment] = c if c
			h
		end

		def to_s ; as_json.to_json end

		def with_comment(str = nil)
			@comment = str
			self
		end

		def self.new_input(cmd, data = {}, cmd_time = nil)
			inner = Command.new cmd, data, cmd_time
			Command.new :input, inner, cmd_time
		end

		def self.from_json(json)
			Command.new json['cmd'].to_sym, json['data'], (json['time'] rescue nil)
		end
	end

	class FileCommandStage < InlineKeyRouter
		attr_reader :path
		attr_reader :mode
		attr_reader :file

		meth_dest :open
		meth_dest :sync
		meth_dest :close
		meth_dest :input

		signal_dest :open
		signal_dest :close
		signal_dest :sync

		def map_chunk(name, c)
			return c if c.kind_of?(Command)
			return Command.new(c) if c.kind_of?(Symbol)
			Command.new(*c)
		end

		def chunk_key(name, c) ; c.cmd end
		def chunk_val(name, c) ; c.data end
		def set_opts!(name, c, k, v, opts_in)
			opts_in[:time]    = c.time 
			opts_in[:comment] = c.comment
		end

		def on_open(k, c)			
			if @file
				signal_error ArgumentError.new("associated file already open")
			else
				@path   = c[:path] if c[:path]
				@mode   = c[:mode] if c[:mode]
				@mode ||= init_mode
				@file = File.open @path, @mode
			end
		end

		def on_input(k, c)
			exit << c rescue nil
		end

		def on_sync(k, c)
			f = @file ;	sync_file f if f
		end

		def on_close(k, c)
			if @file
				begin
					close_file(@file)
				ensure
					@file = nil
				end
			else
				signal_error ArgumentError.new("associated file not open")
			end
		end		

		protected

		def close_file(f)
			begin
				sync_file f
			ensure
				f.close
			end
		end

		def sync_file(f) ; end
	end

	class CommandWriter < FileCommandStage

		def init_mode ; 'w' end

		def on_input(k, c)
			signal_error ArgumentError.new("associated filed not open") unless file
			cmd  = c.cmd
			raise ArgumentError, "invalid commando" unless cmd.kind_of?(Symbol)
			data = c.data
			str  = if data then data.to_json else '' end
			len  = str.length + 1
			tim  = c.time if c.time
			tim  = Time.now unless tim
			tim  = tim.to_i unless tim.kind_of?(Fixnum)
			new_str = ''
			str.each_line { |line| new_str << "... #{line}\n" }
			str  = nil
			len  = new_str.length
			c    = opts[:comment]
			c.each_line { |line| file.write "\# #{line}\n" } if c
			file.write "<<< ANDROMEDA START :#{cmd} TIME #{tim} LEN #{len} >>>\n"
			file.write new_str
			file.write "<<< ANDROMEDA END :#{cmd} >>>\n"
			super k, c
		end

		protected

		def sync_file(f)
			f.sync
			f.fsync rescue nil
		end		
	end

	class CommandReader < FileReader
		attr_reader :start_matcher, :end_matcher, :comment_matcher, :line_matcher

		def initialize(config = {})
			super config
			@start_matcher   = /<<< ANDROMEDA START :(\w+) TIME (\d+) LEN (\d+) >>>/
			@end_matcher     = /<<< ANDROMEDA END :(\w+) >>>/
			@comment_matcher = /#(.*)/
			# remember to change the offset for :line, too whenever you change this
			@line_matcher    = /... (.*)/
		end

		def match_line(state, line)			
			m = @start_matcher.match line
			return yield :start, state, ({ cmd: m[1].to_sym, tim: m[2].to_i, len: m[3].to_i }) if m
			m = @end_matcher.match line
			return yield :end, state, m[1].to_sym if m
			m = @comment_matcher.match line 
			return yield :comment, state, m[1] if m
			m = @line_matcher.match line
			return yield :line, state, m[1] if m
			yield :garbage, state, line
		end

		def on_enter(k, c)
			super k, c do |file|
				fst = opts[:first]
				lst = opts[:last]

				state = { :comment => true, :start => true }			
				while (line = file.gets)
					line = line.chomp
					match_line(state, line) do |token, state, parts|
						signal_error ArgumentError.new("Skipping unexpected token #{token} in line '#{line}' (state: #{state})") unless state[token]
						case token
						when :comment
							if state[:comment_str] 
								then state[:comment_str] << parts 
								else state[:comment_str]  = parts end
						when :start
							state.delete :comment
							state.delete :start
							state[:line]    = true
							state[:end]     = true
							parts[:data]    = ''
							state[:len]     = 0
							state[:cur]     = parts
							parts[:comment] = state[:comment_str]
							state.delete :comment_str
						when :line
							state[:len] += parts.length + 5
							state[:cur][:data] << "#{parts}\n"
						when :end
							state.delete :line
							state.delete :end
							state[:start]   = true
							state[:comment] = true
							cur             = state[:cur]
							data            = cur[:data]
							signal_error ArgumentError.new("Start (#{cur[:cmd]}) and end (#{parts})command mismatch") unless cur[:cmd] == parts
							signal_error ArgumentError.new("Length mismatch (expected: #{cur[:len]}, found: #{state[:len]})") unless cur[:len] == state[:len]
							exit << cur rescue nil							
						else
							signal_error ArgumentError.new("Garbage encountered (line: '#{line}')")
							return
						end
					end
				end
			end
		end

	end

	class CommandParser < Stage

		def on_enter(k, c)
			data = c[:data].chomp
			data = JSON::parse(data)
			cmd  = Command.new c[:cmd], data, c[:time]
			rem  = c[:comment] rescue nil
			cmd.with_comment rem if rem
			exit << cmd rescue nil
		end		
	end

end
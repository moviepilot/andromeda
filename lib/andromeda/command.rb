module Andromeda

	class Command
		attr_reader :cmd
		attr_reader :data
		attr_reader :time

		def initialize(cmd, data = {}, cmd_time = nil)
			raise ArgumentError unless cmd.kind_of?(Symbol)
			@cmd  = cmd
			@data = data
			@time = if cmd_time then cmd_time else Time.now.to_i end
		end

		def if_cmd(sym) ; if sym == cmd then yield data else seld end end

		def as_json ; { cmd: cmd, data: (data.as_json rescue data), time: time } end
		def to_s ; as_json.to_json end

		def self.new_input(cmd, data = {}, cmd_time = nil)
			Command.new(:input, Command.new(cmd, data, cmd_time), cmd_time)
		end
	end

	class FileCommandStage < InlineKeyRouter
		attr_reader :path
		attr_reader :mode
		attr_reader :file

		meth_dest :open
		meth_dest :close
		meth_dest :input

		signal_dest :open
		signal_dest :close

		def map_chunk(name, c)
			return c if c.kind_of?(Command)
			return Command.new(c) if c.kind_of?(Symbol)
			Command.new(*c)
		end

		def chunk_key(name, c) ; c.cmd end
		def chunk_val(name, c) ; c.data end
		def set_opts!(name, c, k, v, opts_in) ; opts_in[:time] = c.time end

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
			emit << c rescue nil
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
				sync_file(f)
			ensure
				f.close
			end
		end

		def sync_file(f) ; end
	end

	class CommandWriter < FileCommandStage

		def init_mode ; 'w+' end

		def on_input(k, c)
			signal_error ArgumentError.new("associated filed not open") unless file
			cmd  = c.cmd
			raise ArgumentError, "invalid commando" unless cmd.kind_of?(Symbol)
			data = c.data
			str  = if data then data.to_json.dump else '' end
			len  = str.length + 1
			tim  = c.time if c.time
			tim  = Time.now unless tim
			tim  = tim.to_i unless tim.kind_of?(Fixnum)
			file.write "<<< ANDROMEDA START :#{cmd} TIME #{tim} LEN #{len.to_i} >>>\n"
			file.write str
			file.write "\n<<< ANDROMEDA END :#{cmd} >>>\n"
			super k, c
		end

		protected

		def sync_file(f)
			f.sync
			f.fsync rescue nil
		end		
	end

	class CommandParser < FileReader

		attr_reader :start_matcher
		attr_reader :end_matcher

		def initialize(config = {})
			@start_matcher   = /^<<< ANDROMEDA START :(\w+) TIME (\d+) LEN (\d+) >>>$/
			@end_matcher     = /^<<< ANDROMEDA END :(\w+) >>>$/
		end

		def match_line(line)			
			if (match = start_matcher.match(line)) then 
				yield :start, ({ cmd: match[1].to_sym, tim: match[2].to_i, len: match[3].to_i })
				return 
			end
			if (match = end_matcher.match(line)) then 
				yield :end, match[1].to_sym
				return 
			end
			yield :line, line
		end

		def on_enter(k, c)
			super k, c do |f|
				fst = opts[:first]
				lst = opts[:last]

				scan = :start
				cur  = nil

				while (line = file.gets)
					match_line do |token, parts|
						signal_error ArgumentException.new("Skipping unexpected token #{token} in line '#{line}' (wanted token from: #{scan})") unless token == scan
						case token
						when :start
							scan = :line
							cur  = parts
						when :line

						when :end

						end
					end
				end
			end
		end

	end


	# 	def on_enter(k, c)
	# 		parser        = dest(:parse)
	# 			match = start_matcher.match line
	# 			if match
	# 				cmd = match[1].to_sym
	# 				tim = match[2].to_i
	# 				len = match[3].to_i
	# 				buf = if len == 0 then '' else file.gets end
	# 				while buf.length < len
	# 					log.debug line
	# 					buf << line
	# 				end
	# 				line  = file.gets.chomp
	# 				match = end_matcher.match line
	# 				if match
	# 					end_cmd = match[1].to_sym
	# 					raise ArgumentError, "command name mismatch between START ('#{cmd}') and END ('#{end_cmd}')" unless cmd == end_cmd
	# 					raise ArgumentError, "length mismatch" unless len == buf.length
	# 					h = { :cmd => end_cmd, :data => buf, :time => tim }
	# 					parser << h
	# 				else
	# 					raise ArgumentError, "garbage commando end: '#{line}'"
	# 				end
	# 			else
	# 				raise ArgumentError, "garbage commando start: '#{line}'"
	# 			end
	# 		end
	# 	end

	# 	def on_parse(k, c)
	# 		data = c[:data]
	# 		c[:data] = if data.chomp == '' then nil else JSON::parse(data) end
	# 		emit << (Commando.new c[:cmd], c[:data], c[:time]) rescue nil
	# 	end
	# end
end
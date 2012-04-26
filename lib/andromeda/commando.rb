module Andromeda

	class CommandoStage < Stage
		attr_reader :file
		attr_reader :path
	end

	class Commando
		attr_reader :cmd
		attr_reader :data
		attr_reader :time

		def initialize(cmd, data = {}, cmd_time = nil)
			raise ArgumentError unless cmd.kind_of?(Symbol)
			@cmd  = cmd
			@data = data
			@time = if cmd_time then cmd_time else Time.now.to_i end
		end

		def as_json ; { cmd: cmd, data: data, time: time } end

		def to_s ; as_json.to_json end
	end

	class CommandoWriter < CommandoStage

		def initialize(config = {})
			super config
			@mode ||= 'a+'
			@file   = File.open path, @mode
		end

		def on_enter(k, c)
			if c == :close
				file.sync
				file.fsync rescue nil
				file.close
			else
				c    = c.as_json.respond_to?(:as_json)
				cmd  = c[:cmd]
				raise ArgumentError, "invalid commando" unless cmd.kind_of?(Symbol)
				data = c[:data]
				str  = if data then data.to_json else '' end
				len  = str.length
				len += 1 unless str.end_with?('\n')
				tim  = c[:time] if c[:time]
				tim  = Time.now unless tim
				tim  = tim.to_i unless tim.kind_of?(Fixnum)
				file.write ">>> ANDROMEDA_COMMANDO :#{cmd} TIME #{tim} LEN #{len.to_i} START\n"
				file.write(str) if data
				if str.end_with?('\n')
					file.write "<<< ANDROMEDA_COMMANDO :#{cmd} END\n"
				else
					file.write "\n<<< ANDROMEDA_COMMANDO :#{cmd} END\n"
				end
			end
		end
	end

	class CommandoParser < CommandoStage

		def initialize(config = {})
			super config
			@file = File.open path, 'r'
		end

		def on_enter(k, c)
			parser        = dest(:parse)
			start_matcher = />>> ANDROMEDA_COMMANDO :(\w+) TIME (\d+) LEN (\d+) START/
			end_matcher   = /<<< ANDROMEDA_COMMANDO :(\w+) END/
			while (line = file.gets)
				line  = line.chomp
				match = start_matcher.match line
				if match
					cmd = match[1].to_sym
					tim = match[2].to_i
					len = match[3].to_i
					buf = if len == 0 then '' else file.gets end
					while buf.length < len
						log.debug line
						buf << line
					end
					line  = file.gets.chomp
					match = end_matcher.match line
					if match
						end_cmd = match[1].to_sym
						raise ArgumentError, "command name mismatch between START ('#{cmd}') and END ('#{end_cmd}')" unless cmd == end_cmd
						raise ArgumentError, "length mismatch" unless len == buf.length
						h = { :cmd => end_cmd, :data => buf, :time => tim }
						parser << h
					else
						raise ArgumentError, "garbage commando end: '#{line}'"
					end
				else
					raise ArgumentError, "garbage commando start: '#{line}'"
				end
			end
		end

		def on_parse(k, c)
			data = c[:data]
			c[:data] = if data.chomp == '' then nil else JSON::parse(data) end
			emit << (Commando.new c[:cmd], c[:data], c[:time]) rescue nil
		end
	end
end
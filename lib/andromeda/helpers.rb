module Andromeda

	def self.mk_tee(config = {}) ; Andromeda::Tee.new(config) end

	class Transf < Stage
		attr_accessor :filter
		attr_accessor :mapper

		def send_chunk(name, meth, k, chunk)
			if signal_name?(name)
				super name, meth, k, chunk
			else
				filter_ = filter
				mapper_ = mapper
				if !(filter_ && filter_.call(chunk))
					super name, meth, k, if mapper_ then mapper_.call(chunk) else chunk end
				end
			end
		end		
	end

	class Tee < Transf
		attr_accessor :level
		attr_accessor :other
		attr_accessor :delay

		def init_pool_config ; :local end

		def initialize(config = {})
			super config
			@level ||= :info
		end

		def on_enter(k, c)
			log_   = log
			level_ = level
			sleep delay.to_i if delay
			log_.send level, "TEE #{ident}.#{current_name}, key: #{k} chunk: #{c} opts: #{opts}" if log_ && level_
			other << c rescue nil
			super k, c
		end
	end

	class Targeting < Transf
		attr_accessor :targets

		def initialize(config = {})
			super config
			@targets ||= {}
		end

		def target_values ; t = targets ; t.values rescue t end
	end

	class Broadc < Targeting
		def on_enter(k, c)
			target_values { |t| intern(t) << o rescue nil }
		end		
	end

	class Switch < Targeting
		def on_enter(k, c)
			(intern(k) rescue exit) << c rescue nil
		end
	end

	class FifoStage < Stage
		def init_pool_config ; :fifo end
	end

	class SingleStage < Stage
		def init_pool_config ; :single end
	end

	class InlineKeyRouter < SingleStage
		def on_enter(k, c)
			dest(k).call_inline k, c
		end
	end

	class Gatherer < Stage
		def init_pool_config ; :single end
	end

	class Reducer < Gatherer
		attr_accessor :state
		attr_accessor :reducer		

		meth_dest :new_state

		def on_enter(k, c)
			reducer_ = reducer

			state_   = state
			new_     = reducer_.call state_, k, c
			unless new_ == state_
				state = new_
				new_state.submit_now state
			end
		end

		def on_new_state(k, c)
			self.exit.submit_now c rescue nil
		end
	end

	class FileReader < Stage
		attr_reader :path
		attr_reader :mode

		def set_opts!(name, chunk, key, val, opts_in)
			opts_in[:first] = chunk.first rescue 0
			opts_in[:last]  = chunk.last rescue -1
		end

		protected

		def on_enter(k, c)
			file = File.open path, mode
			begin
					file.seek opts[:first]
					opts[:last] = file.size - 1 if opts[:last] < 0
					opts[:num]  = opts[:last] - opts[:first]
					if block_given? then yield file else super k, c end 
			ensure
				file.close
			end
		end

	end

	class FileChunker < FileReader
		attr_reader :num_chunks

		def initialize(config = {})
			super config
			@num_chunks ||= PoolSupport.num_processors
		end

		def on_enter(k, c)
			num_c = num_chunks
			super k, c do |f|
				fst = opts[:first]
				lst = opts[:last]
				sz  = opts[:num] / num_c rescue 1
				sz  = 1 if sz < 0
				while fst <= lst
					nxt = fst + sz
					nxt = lst if nxt > lst 
					exit << Range.new(fst, nxt)
					fst = nxt + 1
				end
			end
		end
	end
end
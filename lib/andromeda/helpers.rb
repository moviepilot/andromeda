module Andromeda

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
			(intern(k) rescue emit) << c rescue nil
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
			self.emit.submit_now c rescue nil
		end
	end

end
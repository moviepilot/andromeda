module Andromeda

	class Transf < Base
		attr_accessor :filter
		attr_accessor :mapper

		def output(k, c)
			filter_  = filter
			mapper_  = mapper
			if !filter_ || filter_.call(k, c)
				c = if mapper_ then mapper_.call k, c else [c] end
				yield k, c
			end
		end

		def on_enter(k, c)
			output(k, c) { |k, o| super k, o } 
		end
	end

	class Tee < Transf
		attr_accessor :level
		attr_accessor :other

		def init_pool_config ; :local end

		def initialize(config = {})
			super config
			@level ||= :info
		end

		def on_enter(k, c)
			log_   = log
			level_ = level
			log_.send level, "TEE key: #{k} chunk: #{c}" if log_ && level_
			other << c rescue nil
			super k, c
		end
	end

	class TargetBase < Transf
		attr_accessor :targets

		def initialize(config = {})
			super config
			@targets ||= {}
		end

		def target_values ; t = targets ; t.values rescue t end
	end

	class Broadc < TargetBase
		def on_enter(k, c)
			output(k, c) do |k, o|
				target_values { |t| intern(t) << o rescue nil }
			end
		end		
	end

	class Switch < TargetBase
		def on_enter(k, c)
			output(k, c) { |k, o| (intern(k) rescue emit) << o }
		end
	end

	class Router < TargetBase
		def chunk_key(name, c) ; c[0] end

		def on_enter(k, c)
			output(k, c[1]) { |k, o| (intern(k) rescue emit) << o }
		end
	end

	class FifoBase < Base
		def init_pool_config ; :fifo end
	end

	class GathererBase < Base
		def init_pool_config ; :single end
	end

	class Reducer < GathererBase
		attr_accessor :state
		attr_accessor :reducer

		def on_enter(k, c)
			reducer_ = reducer

			state_   = state
			new_     = reducer_.call state_, k, c
			unless new_ == state_
				state = new_
				super k, new_ 
			end
		end
	end
	
end
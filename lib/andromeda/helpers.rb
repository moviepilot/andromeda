module Andromeda

	class Transf < Base
		attr_accessor :filter
		attr_accessor :mapper

		def send_chunk(meth, k, chunk)
			filter_ = filter
			mapper_ = mapper
			if !(filter_ && filter_.call(chunk))
				super meth, k, if mapper_ then mapper_.call(chunk) else chunk end
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
			log_.send level, "Andromeda::TEE ident: #{ident} key: #{k} chunk: #{c} opts: #{opts}" if log_ && level_
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
			target_values { |t| intern(t) << o rescue nil }
		end		
	end

	class Switch < TargetBase
		def on_enter(k, c)
			(intern(k) rescue emit) << c rescue nil
		end
	end

	class Router < Switch
		def chunk_key(name, c) ; c[:key] end
		def chunk_val(name, key, c) ; c[:val] end
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
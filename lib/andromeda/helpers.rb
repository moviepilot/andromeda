module Andromeda


	class Join < Base

		def initialize(config = {})
			super config
			@mutex = Mutex.new
			@cv    = ConditionVariable.new
			#  box value to keep ref after clone
			@state = [ state_init ]
		end

		protected

		def state_init ; {} end
		def state_key(chunk) ;  chunk end
		def state_complete?(state) ; state end
		def state_updatable?(state, chunk) ;  state[state_key(chunk)] == nil end
		def state_update(state, chunk) ; state[state_key(chunk)] = chunk end

	    def run(pool, scope, meth, chunk, &thunk)
	    	@mutex.synchronize {
	    		state = @state[0]
	    		while true
	    			if state_updatable?(state, chunk)
	    				@state[0] = (state = state_update(state, chunk))
	    				if state_complete?(state)
	    					super pool, scope, meth, state, &thunk
	    					@state[0] = state_init
	    				end
						cv.signal
						return
	    			else
	    				cv.wait
	    			end
	    		end
	    	}
	    end

	end

	class Transf < Base
		attr_accessor :filter
		attr_accessor :mapper
		attr_accessor :reducer

		def output(c)
			filter_  = filter
			mapper_  = mapper
			reducer_ = reducer
			if !filter_ || filter_.call(c)
				c = if mapper_ then mapper_.call c else [c] end
				c = reducer_.call c if reducer_
				yield c
			end
		end

		def on_enter(c)
			output(c) { |o| super o } 
		end
	end

	class Tee < Transf
		attr_accessor :level

		def init_pool_config ; :local end

		def initialize(config = {})
			super config
			@level ||= :info
		end

		def on_enter(c)
			log_   = log
			level_ = level
			log_.send level, "#{c}" if log_ && level_
			super c
		end
	end

	class Targeting < Transf
		attr_accessor :targets

		def initialize(config = {})
			super config
			@targets ||= {}
		end

		def target_values
			t = targets
			if t.kind_of?(Hash)	then t.values else t end
		end

		def switch_target(c)
			switch_ = switch
			switch_ = switch_.call(c) if switch_
			targets[switch_]
		end
	end

	class Broadc < Targeting
		def on_enter(c)
			output(c) do |o|
				target_values { |t| intern(t) << o rescue nil }
			end
		end		
	end

	class Switch < Targeting
		attr_accessor :switch

		def on_enter(c)
			target_ = intern(switch_target c) rescue emit
			output(c) { |o| target_ << o }
		end
	end

	class Router < Targeting
		def on_enter(c)
			target_ = intern(switch_target c[0]) rescue emit
			output(c[1]) { |o| target_ << o }
		end
	end

	class FifoBase < Base
		def init_pool_config ; :fifo end
	end

	class LocalBase < Base
		def init_pool_config ; :local end
	end

end
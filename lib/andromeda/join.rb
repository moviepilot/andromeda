module Andromeda

	# untested as in not at all but should would perfectly fine according to theory

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

		# typical usages need to override these two
		def state_key(chunk) ; chunk end
		def state_complete?(state)  state end

		def state_updatable?(state, chunk) ;  state[state_key(chunk)] == nil end
		def state_update(state, chunk) ; state[state_key(chunk)] = chunk; state end

	    def run(pool, scope, meth, chunk, &thunk)
	    	@mutex.synchronize do
	    		state = @state[0]
	    		while true
	    			if state_updatable?(state, chunk)
	    				@state[0] = (state = state_update(state, chunk))
	    				if state_complete?(state)
	    					@state[0] = state_init
							cv.signal
	    					return super pool, scope, meth, state, &thunk
	    				else
	    					cv.signal
	    					return self
	    				end
	    			else
	    				cv.wait @mutex
	    			end
	    		end
	    	end
	    end

	end
end	
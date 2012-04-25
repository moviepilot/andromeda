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

		def state_ready?(state)
			raise RuntimeException, 'Not implemented'
		end

		def state_empty?(state, k, chunk)  ; state[k].nil? end
		def state_updated(state, k, chunk) ; state[k] = chunk; state end

		def state_chunk_key(name, state) ; chunk_key(name, state) end

	    def run_chunk(pool, scope, name, meth, k, chunk, &thunk)
	    	@mutex.synchronize do
	    		state = @state[0]
	    		while true
	    			if state_empty?(state, k, chunk)
	    				@state[0] = (state = state_updated(state, k, chunk))
	    				if state_ready?(state)
	    					@state[0] = state_init
							cv.signal
							new_k = state_chunk_key(name, state)
	    					return super pool, scope, name, meth, new_k, state, &thunk
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
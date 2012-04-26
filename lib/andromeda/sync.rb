module Andromeda

	class Join < Stage

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

	# Passes all input and waits for the associated scope to return to the start value
	# (will only work if there is no concurrent modification to the associated scope)
	class ScopeWaiter < Stage

		def on_enter(k, v)
			scope_ = current_scope
			value_ = scope_.value
			super k, v
			scope_.wait_for value_
		end

	end	
end	
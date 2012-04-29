module Andromeda

	module Kit

		class Transf < Plan
			attr_accessor :filter
			attr_accessor :mapper

			def deliver_data(name, meth, k, data, tags_in)
				if signal_name?(name)
					super name, meth, k, data, tags_in
				else
					filter_ = filter
					mapper_ = mapper
					if !(filter_ && filter_.call(data))
						super name, meth, k, (if mapper_ then mapper_.call(data) else data end), tags_in
					end
				end
			end
		end

		class Tee < Transf
			attr_accessor :level
			attr_accessor :other
			attr_accessor :delay

			def initialize(config = {})
				super config
				@level ||= :info
			end

			def on_enter(k, v)
				log_   = log
				level_ = level
				sleep delay.to_i if delay
				if log_ && level_
					cur_name = current_name
					key_str  = Andromeda::Impl::To_S.short_s k
					val_str  = Andromeda::Impl::To_S.short_s v
					log_str  = "#{to_s}.#{cur_name}(#{key_str}, #{val_str})"
					tags.each_pair { |k, v|	log_str << " #{k}=#{Andromeda::Impl::To_S.short_s(v)}" }
					log_str << " tid=0x#{Thread.current.object_id.to_s(16)}"
					log_.send level, log_str
				end
				other_ = other
				other_ << v if other_
				super k, v
			end
		end

		# class Targeting < Transf
		# 	attr_accessor :targets

		# 	def initialize(config = {})
		# 		super config
		# 		@targets ||= {}
		# 	end

		# 	def target_values ; t = targets ; t.values rescue t end
		# end

		# class Broadc < Targeting
		# 	def on_enter(k, c)
		# 		target_values { |t| intern(t) << o rescue nil }
		# 	end
		# end

		# class Switch < Targeting
		# 	def on_enter(k, c)
		# 		(intern(k) rescue exit) << c rescue nil
		# 	end
		# end

		# class FifoPlan < Plan
		# 	def init_pool_config ; :fifo end
		# end

		# class SinglePlan < Plan
		# 	def init_pool_config ; :single end
		# end

		# class InlineKeyRouter < SinglePlan
		# 	def on_enter(k, c)
		# 		Spot(k).call_inline k, c
		# 	end
		# end

		# class Gatherer < Plan
		# 	def init_pool_config ; :single end
		# end

		# class Reducer < Gatherer
		# 	attr_accessor :state
		# 	attr_accessor :reducer

		# 	meth_Spot :new_state

		# 	def on_enter(k, c)
		# 		reducer_ = reducer

		# 		state_   = state
		# 		new_     = reducer_.call state_, k, c
		# 		unless new_ == state_
		# 			state = new_
		# 			new_state.submit_now state
		# 		end
		# 	end

		# 	def on_new_state(k, c)
		# 		self.exit.submit_now c rescue nil
		# 	end
		# end

		# class FileReader < Plan
		# 	attr_reader :path
		# 	attr_reader :mode

		# 	def set_opts!(name, chunk, key, val, opts_in)
		# 		opts_in[:first] = chunk.first rescue 0
		# 		opts_in[:last]  = chunk.last rescue -1
		# 	end

		# 	protected

		# 	def on_enter(k, c)
		# 		file = File.open path, mode
		# 		begin
		# 				file.seek opts[:first]
		# 				opts[:last] = file.size - 1 if opts[:last] < 0
		# 				opts[:num]  = opts[:last] - opts[:first]
		# 				if block_given? then yield file else super k, c end
		# 		ensure
		# 			file.close
		# 		end
		# 	end

		# end

		# class FileChunker < FileReader
		# 	attr_reader :num_chunks

		# 	def initialize(config = {})
		# 		super config
		# 		@num_chunks ||= PoolSupport.num_processors
		# 	end

		# 	def on_enter(k, c)
		# 		num_c = num_chunks
		# 		super k, c do |f|
		# 			fst = opts[:first]
		# 			lst = opts[:last]
		# 			sz  = opts[:num] / num_c rescue 1
		# 			sz  = 1 if sz < 0
		# 			while fst <= lst
		# 				nxt = fst + sz
		# 				nxt = lst if nxt > lst
		# 				exit << Range.new(fst, nxt)
		# 				fst = nxt + 1
		# 			end
		# 		end
		# 	end
		# end

		# class Join < Plan

		# 	def initialize(config = {})
		# 		super config
		# 		@mutex = Mutex.new
		# 		@cv    = ConditionVariable.new
		# 		#  box value to keep ref after clone
		# 		@state = [ state_init ]
		# 	end

		# 	protected

		# 	def state_init ; {} end

		# 	def state_ready?(state)
		# 		raise RuntimeException, 'Not implemented'
		# 	end

		# 	def state_empty?(state, k, chunk)  ; state[k].nil? end
		# 	def state_updated(state, k, chunk) ; state[k] = chunk; state end

		# 	def state_chunk_key(name, state) ; chunk_key(name, state) end

		#     def run_chunk(pool, scope, name, meth, k, chunk, &thunk)
		#     	@mutex.synchronize do
		#     		state = @state[0]
		#     		while true
		#     			if state_empty?(state, k, chunk)
		#     				@state[0] = (state = state_updated(state, k, chunk))
		#     				if state_ready?(state)
		#     					@state[0] = state_init
		# 						cv.signal
		# 						new_k = state_chunk_key(name, state)
		#     					return super pool, scope, name, meth, new_k, state, &thunk
		#     				else
		#     					cv.signal
		#     					return self
		#     				end
		#     			else
		#     				cv.wait @mutex
		#     			end
		#     		end
		#     	end
		#     end

		# end

		# # Passes all input and waits for the associated scope to return to the start value
		# # (will only work if there is no concurrent modification to the associated scope)
		# class ScopeWaiter < Plan

		# 	def on_enter(k, v)
		# 		scope_ = current_scope
		# 		value_ = scope_.value
		# 		super k, v
		# 		scope_.wait_for value_
		# 	end

		# end

	end
end
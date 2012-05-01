module Andromeda

	module Kit

		module Transf
			attr_accessor :filter
			attr_accessor :mapper

			def deliver_data(name, meth, key, val, tags_in)
				if signal_name?(name)
					super name, meth, key, val, tags_in
				else
					filter_ = filter
					mapper_ = mapper
					if !(filter_ && filter_.call(val))
						super name, meth, key, (if mapper_ then mapper_.call(val) else val end), tags_in
					end
				end
			end
		end

		class Tee < Plan
			attr_accessor :level
			attr_accessor :other
			attr_accessor :delay

			def initialize(config = {})
				config = { nick: config } unless config.is_a? Hash || config.is_a?(Spot)
				config = { other: config } unless config.is_a? Hash
				super config

				@level ||= :info
			end

			def initialize_copy(other)
				@level = other.level.identical_copy
				@delay = other.delay.identical_copy
			end

			def on_enter(key, val)
				log_   = log
				level_ = level
				sleep delay.to_i if delay
				if log_ && level_
					cur_name = current_name
					key_str  = Andromeda::Impl::To_S.short_s key
					val_str  = Andromeda::Impl::To_S.short_s val
					log_str  = "#{to_s}.#{cur_name}(#{key_str}, #{val_str})"
					tags.each_pair { |k, v|	log_str << " #{k}=#{Andromeda::Impl::To_S.short_s(v)}" }
					log_str << " tid=0x#{Thread.current.object_id.to_s(16)}"
					log_.send level, log_str
				end
				other_ = other
				other_ << val if other_
				super key, val
			end
		end

		class Targeting < Plan
			attr_accessor :targets

			def initialize(config = {})
				super config
				@targets ||= {}
			end

			def target_values ; t = targets ; t.values rescue t end
		end

		class Broadc < Targeting
			def on_enter(key, val)
				target_values { |t| intern(t) << val rescue nil }
			end
		end

		class Switch < Targeting
			def on_enter(key, val)
				(intern(key) rescue exit) << val rescue nil
			end
		end

		class SinglePlan < Plan
	    def init_guide ; Guides::SinglePoolGuide.new end
		end

		class InlineKeyRouter < SinglePlan
			def key_spot(name, key) ; key end
		end

		class Gatherer < SinglePlan
			include Transf
		end

		class Reducer < Gatherer
			attr_accessor :state
			attr_accessor :reducer

			attr_spot :new_state

			def on_enter(key, val)
				reducer_ = reducer

				state_   = state
				new_     = reducer_.call state_, key, val
				unless new_ == state_
					state = new_
					new_state << state if new_state
				end
			end
		end

		class FileReader < Plan
			attr_reader :path
			attr_reader :mode

			def initialize(config = {})
				super config
				@mode ||= init_mode
			end

			def data_tag(name, key, val, tags_in)
				tags_out         = super
				tags_out[:first] = val.first rescue 0
				tags_out[:last]  = val.last rescue -1
				tags_out
			end

			def init_mode ; 'r' end

			protected

			def on_enter(key, val)
				file = File.open path, mode
				begin
						file.seek tags[:first]
						tags[:last] = file.size - 1 if tags[:last] < 0
						tags[:num]  = tags[:last] - tags[:first]
						if block_given? then yield file else super key, val end
				ensure
					file.close
				end
			end

		end

		class FileChunker < FileReader
			attr_reader :num_chunks

			def initialize(config = {})
				super config
				@num_chunks ||= Guides::PoolGuide.num_procs
			end

			def on_enter(key, val)
				num_c = num_chunks
				super key, val do |f|
					fst = tags[:first]
					lst = tags[:last]
					sz  = tags[:num] / num_c rescue 1
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
end
require 'atomic'

module Andromeda

	class Region

		def initialize(init_value = 0)
			init_value = init_value[:init_value].to_i if init_value.kind_of?(Hash)
			raise ArgumentError unless init_value.kind_of?(Fixnum)
			@count = Atomic.new init_value
		end

		def value ; @count.value end

		def enter(amount = 1)
			raise ArgumentError unless amount.kind_of?(Fixnum)
			raise ArgumentError unless amount >= 0
			@count.update { |v| v + amount }
		end

		def leave(amount = 1)
			raise ArgumentError unless amount >= 0
			raise ArgumentError unless amount.kind_of?(Fixnum)
			@count.update { |v| v - amount }
		end

		def wait_while(&test)
			while test.call(value)
				Thread::pass
			end
		end

		def wait_for(val = 0)
			raise ArgumentError unless val.kind_of?(Fixnum)
			wait_while { |v| v != val }
		end
	end

end
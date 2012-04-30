module Andromeda

	module Impl

		class Atom < Atomic
			include To_S

			def initialize(init_val = nil)
				super init_val
			end

			def empty? ; value.nil? end
			def full? ; ! value.nil? end

			def to_short_s ; "(#{To_S.short_s(value)})" end
			alias_method :inspect, :to_s

			def wait_while(&test)
				while test.call(value) ; Thread::pass	end
			end

			def wait_until_eq(val = nil)
				raise ArgumentError unless val.kind_of?(Fixnum)
				wait_while { |v| v != val }
			end

			def wait_until_ne(val = nil)
				raise ArgumentError unless val.kind_of?(Fixnum)
				wait_while { |v| v == val }
			end

			def wait_until_empty?
				wait_until_eq nil
			end

			def wait_until_full?
				wait_until_ne nil
			end

			def with_value
				update { |v| yield v ; v }
			end
		end

	end

	module Atom

		class Region
			include Impl::To_S

			def to_short_s ; "(#{Impl::To_S.short_s(value)})" end
			alias_method :inspect, :to_s

			def initialize(init_value = 0)
				init_value = init_value[:init_value].to_i if init_value.kind_of?(Hash)
				raise ArgumentError unless init_value.kind_of?(Fixnum)
				@count = Impl::Atom.new init_value
			end

			alias_method :inspect, :to_s

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

			def wait_until_eq(val) ; @count.wait_until_eq(val) end
		end

		class Var < Impl::Atom
		end

		class FillOnce < Var
			def empty! ; super.update nil end

			def update(v)
				super.update do |o|
					raise ArgumentError, 'Attempt to refill FillOnce' if o
					v
				end
			end
		end

		class Combiner < Var
			attr_reader :combiner

			def update(v)
				super.update do |o|
					if combiner then combiner.call o, v else v end
				end
			end
		end

	end
end
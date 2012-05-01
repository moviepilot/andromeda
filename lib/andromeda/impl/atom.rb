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
          while test.call(value) ; Thread::pass end
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

  end
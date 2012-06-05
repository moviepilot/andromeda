module Andromeda

  module Guides

    class PoolGuide < Guide
      attr_reader :max_procs
      attr_reader :pool_track

      # @return [Fixnum] number of processors as determined by Facter
      def self.num_procs
        if ENV['NUM_PROCS']
          @num_procs = ENV['NUM_PROCS'].to_i
        end
        case RUBY_PLATFORM
        when 'java'
          @num_procs = java.lang.Runtime.get_runtime.available_processors unless defined?(@num_procs)
        else
          @num_procs = Facter.sp_number_processors.strip.to_i unless defined?(@num_procs)
        end
        @num_procs
      end

      def initialize(num_procs = nil)
        num_procs  = PoolGuide.num_procs unless num_procs
        raise ArgumentError unless num_procs.is_a?(Fixnum)
        raise ArgumentError unless num_procs > 0
        @max_procs  = num_procs
        @pool_track = PoolTrack.new ThreadPool.new(@max_procs)
      end

      def track(spot, label, suggested_track = nil)
        return suggested_track if suggested_track
        return @pool_track
      end

      def pack(plan, track, was_suggested = false)
        return plan if plan.frozen?
        return plan.identical_copy if was_suggested
        if max_procs > 1 then plan.identical_copy else plan end
      end
    end

    class PoolTrack
      include DispatchingTrack

      attr_reader :pool

      def initialize(pool)
        @pool = pool
      end

      protected

      def process(&thunk)
        # DefaultLogger.instance.info ":enter #{pool.inspect}"
        pool.process &thunk
        # DefaultLogger.instance.info ":exit #{pool.inspect}"
      end
    end

    class SharedPoolGuide < PoolGuide
      include Singleton

      def initialize
        super PoolGuide.num_procs
      end
    end

    class SinglePoolGuide < PoolGuide
      def initialize ; super 1 end
    end

    class SharedSinglePoolGuide < SinglePoolGuide
      include Singleton
    end

  end
end
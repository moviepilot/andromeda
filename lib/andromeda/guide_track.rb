module Andromeda
  module Guides

    class Guide
      include Andromeda::Impl::To_S

      def track(spot, label, suggested_track = nil)
        raise NoMethodError
      end

      def provision(track, label, tags_in)
        tags_out = Hash.new
        tags_out[:scope] = ::Andromeda::Atom::Region.new unless tags_in[:scope]
        tags_out[:label] = label
        tags_out
      end

      def pack(plan, track, was_suggested = false)
        if plan.frozen? then plan else plan.identical_copy end
      end

    end

    class Track
      include Andromeda::Impl::To_S

      def follow(scope, *args, &thunk)
        scope.enter
        begin
          thunk.call *args
        ensure
          scope.leave
        end
      end
    end

    class LocalGuide < Guide
      include Singleton

      def track(spot, key, suggested_track = nil)
        return suggested_track if suggested_track
        LocalTrack.instance
      end
    end

    class LocalTrack < Track
      include Singleton
    end

    module DispatchingTrack

      def follow(scope, *args, &thunk) ; dispatch(scope, *args, &thunk) end

      def process(&thunk)
        thunk.call
      end

      def dispatch(scope, *args, &thunk)
        scope.enter
        begin
          process do
            begin
              thunk.call *args
            ensure
              scope.leave
            end
          end
        rescue
          # In case Thread.new fails
          scope.leave
          raise
        end
      end

      protected :process
      protected :dispatch
    end

    class SpawnGuide < Guide
      include Singleton

      def track(spot, label, suggested_track = nil)
        SpawnTrack.instance
      end
    end

    class SpawnTrack < Track
      include Singleton
      include DispatchingTrack

      protected

      def process(&thunk) ; Thread.new { || Thread.current; thunk.call } end
    end

  end
end
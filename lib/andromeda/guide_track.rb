module Andromeda

  module Guides

  	class Guide
      def track(spot, label, suggested_track = nil)
        raise NoMethodError
      end

      def provision(track, tags_in)
        tags_out = Hash.new
        tags_out[:region] = Scope.new unless tags_in[:scope]
        tags_out
      end

      def pack(track, was_suggested = false)
        return plan.copy if was_suggested
        if plan.frozen? then plan else plan.copy end
      end

  	end

    class Track
      def follow(*args, &thunk) ; thunk.call *args end
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

    class SpawnGuide < Guide
      include Singleton

      def track(spot, label, suggested_track = nil)
        SpawnGuide.instance
      end
    end

    class SpawnTrack < Track
      include Singleton

      def follow(*args, &thunk)
        Thread.new { || thunk.call *args }
      end
    end

  end
end
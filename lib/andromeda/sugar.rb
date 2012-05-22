module Andromeda

  class Plan
    def pool ; guide.pool_track.pool rescue nil end
  end

  module Guides

    def self.default=(new_guide)
      DefaultGuideHolder.instance.guide = new_guide
    end

    def self.default ;  DefaultGuideHolder.instance.guide end

    def self.single ; SinglePoolGuide end
    def self.shared_pool ; SharedPoolGuide end
    def self.pool ; SharedPoolGuide end
    def self.local ; LocalGuide end
    def self.shared_single ; SharedSinglePoolGuide end

    class DefaultGuideHolder
      include Singleton

      attr_accessor :guide

      def initialize
        @guide = LocalGuide
      end
    end

  end

  class DefaultLogger < SimpleDelegator
    include Singleton

    def initialize
      super Logger.new(STDERR)
    end
  end

end

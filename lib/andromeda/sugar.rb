module Andromeda

  class Plan
    def pool ; guide.pool_track.pool rescue nil end
  end

  module Guides

    def self.default ; DefaultGuide.instance end
    def self.single ; SinglePoolGuide.new end
    def self.shared_pool ; SharedPoolGuide end
    def self.pool ; SharedPoolGuide.new end
    def self.local ; LocalGuide end
    def self.shared_single ; SharedSinglePoolGuide end

    class DefaultGuide < SimpleDelegator
      include Singleton

      def initialize
        super LocalGuide.instance
      end

      def instance=(new_instance)
        if new_instance.is_a?(Class) && new_instance.include?(Singleton)
          new_instance = new_instance.instance
        end
        instance.__setobj__ new_instance
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

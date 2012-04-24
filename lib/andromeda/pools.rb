module Andromeda

  # Helper class for easily obtaining a thread pool with num_processors threads
  class PoolSupport
    # @return [Fixnum] number of processors as determined by Facter
    def self.num_processors ; Facter.sp_number_processors.strip.to_i end

    # @return [ThreadPool] a new thread pool with num_processors threads
    def self.new_default_pool ; ThreadPool.new self.num_processors end

    # @return [ThreadPool] a globally shared thread pool with num_processors threads
    def self.global_pool(reset = false)
      @pool = self.new_default_pool unless @pool || reset
      @pool
    end

    # @return [ThreadPool] of size 1
    def self.new_single_pool ; ThreadPool.new(1) end

    # @return [ThreadPool] that guarantees fifo processing of requests
    def self.new_fifo_pool ; new_single_pool end
  end

  # Fake thread pool that spawns an unlimited number of threads
  class SpawnPool
    def process(&block) ; Thread.new &block end

    # @return [SpawnPool] a globally shared SpawnPool instance
    def self.default_pool
      @pool ||= SpawnPool.new
      @pool
    end

    # Does nothing
    def shutdown ; end
  end

  # Caching factory for thread pools
  class PoolFactory < Hash

    attr_reader :pool_maker

    # @yield [Proc] factory/maker for building thread pools for a given key
    def initialize(&pool_maker)
      @pool_maker = pool_maker
    end

    def [](key)
      current = super key
      if ! current
        current   = pool_maker.call key
        self[key] = current
      end
      current
    end

    def []=(key, value)
      raise ArgumentError, "Not a ThreadPool" unless value.respond_to?(:process)
      super key, value
    end

    def shutdown
      values.each { |pool| pool.shutdown }
    end

    alias_method :process_stage, :[]
  end

end
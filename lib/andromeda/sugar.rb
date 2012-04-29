module Andromeda

  class DefaultLogger < SimpleDelegator
    include Singleton

    def initialize
      super Logger.new(STDERR)
    end
  end

  # TODO DefaultTee

end

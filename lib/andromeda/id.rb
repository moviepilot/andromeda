module Andromeda

	class Id < Impl::XorId
		# Default length of generated ids
		DEFAULT_NUM_BYTES = 8

	  # @param [Bool] random
		def initialize(random = true)
			super DEFAULT_NUM_BYTES, random
		end

	  # @return [Id] empty (zero) id
	  def self.zero
	  	@id = self.new false unless defined? @id
	  	@id
	  end
	end

end
module Andromeda

	module Impl

		# Generator for random xorable ids (used for markers)
		class Id
			include To_S

		  protected

		  def initialize(len, random = true, init_data = nil)
		    raise ArgumentError unless len.kind_of?(Fixnum)
		    raise ArgumentError unless len >= 0

	    	@data = if init_data
		    	init_data
		    else
			    if random
			      then len.times.map { Id.rnd_byte }
			      else len.times.map { 0 } end
			 	end
		  end

		  public

	    def clone_to_copy? ; false end
	    def identical_copy ; self end

			def length ; @data.length end
			def zero? ; each { |b| return false unless b == 0 } ; true end

		  def [](key) ; @data[key] end

		  def same_length?(obj) ; self.length == obj.length end

			def each ; this = self ; 0.upto(length-1).each { |i| yield this[i] } end
			def each_with_index ; this = self ; 0.upto(length-1).each { |i| yield i, this[i] } end

		  # Compare self to b
		  # @param [Id] b
		  def ==(b)
		  	return true if self.equal? b
		  	return false if b.nil?
		  	return false unless b.class.equal? self.class
		  	return false unless same_length? b
		    zip_bytes(b) { |i, j| return false if i != j }
		    true
		  end

		  def hash ; @data.hash end

		  # xor self and b's ids component-wise
		  # @param [Array<Fixnum>] b
		  # @return [Id]
		  def xor(b)
		    r = []
		    zip_bytes(b) { |i,j| r << (i ^ j) }
		    Id.new r.length, false, r
		  end

		  def to_short_s
		  	r = ''
		    each { |b| r << Id.two_char_hex_str(b.to_s(16)) }
		    r
		  end

		  def inspect ; to_s end

		  private

		  def zip_bytes(b)
		    a = self
		    0.upto(length-1).each { |i| yield a[i], b[i] }
		  end

		  def self.rnd_byte ; Random.rand(256) end

		  def self.two_char_hex_str(s)
		  	case s.length
		  		when 0 then '00'
		  		when 1 then "0#{s}"
		  		else s
		  	end
		  end
		end
	end

	class Id < Impl::Id
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
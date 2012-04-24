module Andromeda

	# Generator for random xorable ids (used in marks)
	class Id
	  # Default length if generated ids
	  NUM_BYTES = 12

	  protected

	  def initialize(len = NUM_BYTES, random = true, init_data = nil)
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

	  def length ; @data.length end

	  def zero?
	    each { |b| return false unless b == 0 }
	    true
	  end

	  def each ; this = self ; 0.upto(length-1).each { |i| yield this[i] } end

	  def each_with_index ; this = self ; 0.upto(length-1).each { |i| yield i, this[i] } end

	  def zip_bytes(b)
	    return ArgumentError unless same_id_kind?(b)
	    a = self
	    0.upto(length-1).each { |i| yield a[i], b[i] }
	  end
	  def [](key) ; @data[key] end

	  def same_id_kind?(obj) ; obj.kind_of?(Id) && obj.length == self.length end

	  # Compare self to b
	  # @param [Id] b
	  def eq?(b)
	    zip_bytes(b) { |i,j| return false if i != j }
	    true
	  end

	  alias_method :==, :eq?

	  # xor self and b's ids component-wise
	  # @param [Array<Fixnum>] b
	  # @return [Id]
	  def xor(b)
	    r = []
	    zip_bytes(b) { |i,j| r << (i ^ j) }
	    Id.new r.length, false, r
	  end

	  def to_s
	    r = "#<#{self.class}:"
	    each { |b| r << Id.twochars(b.to_s(16)) }
	    r << '>'
	    r
	  end

	  # @param [Fixnum] length
	  # @return [Id] random id
	  def self.gen(length = NUM_BYTES) ;  Id.new length, true end

	  # @param [Fixnum] length
	  # @return [Id] empty (zero) id
	  def self.zero(length = NUM_BYTES) ; Id.new length, false end

	  private

	  def self.rnd_byte ; Random.rand(256) end

	  def self.twochars(s)
	  	case s.length
	  		when 0 then '00'
	  		when 1 then "0#{s}"
	  		else s
	  	end
	  end

	end

end
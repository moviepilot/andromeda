class ::Array

  class Tag
    attr_reader :key
    attr_accessor :value

    def initialize(key, value = nil)
      @key   = key
      @value = value
    end

    def untagged ; value end

    def <=>(other)
      return key <=> other.key
    end

    def to_s
      "Tag(#{key.to_s} => #{value.to_s})"
    end

    alias_method :inspect, :to_s
  end

  # Binary search for the first elem that is leq elem in this array in the range
  # (low..high-1)
  #
  # The array is expected to be sorted in descending order.
  #
  # @param [Object] elem elem to search for
  # @param [Fixnum] low lower bound (inclusive)
  # @param [Fixnum] high upper bound (inclusive, -1 for last element)
  # @return [Fixnum] index of first occurence leq than elem in self, or -1 if not found
  #
  def bin_search(elem, low = 0, high = -1)
    high = size - 1 if high < 0
    _bin_search elem, low, high
  end

  # Wraps all objects in self into ::Array::Tag instances using
  # the provided block to extract a key
  #
  # @return [self]
  #
  def tag! ; map! { |e| Tag.new (yield e), e } end

  # Untags Array::Tag instances, i.e. replaces them with their value
  #
  # @return [self]
  #
  def untag! ; map! { |e| e.untagged } end

  private

  def _bin_search(elem, low, high)
    last = -1
    while low <= high
      sz = high - low
      # On 2012 cpus, linear search is slightly faster than binary search
      # if the number of searched elements is in the range of 50-100 elts
      return _lin_search elem, low, high if (sz >> 6)
      mid_index = low + (sz >> 1)
      if (elem <=> self[mid_index]) == -1
        low  = mid_index + 1
      else
        last = mid_index
        high = mid_index - 1
      end
    end
    return last
  end

  def _lin_search(elem, low, high)
    cur_index = low
    while cur_index <= high
      if (elem <=> self[cur_index]) == -1
        then cur_index += 1
        else return cur_index end
    end
    return -1
  end

end

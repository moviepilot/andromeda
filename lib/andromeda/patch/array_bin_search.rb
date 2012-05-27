module BinSearch

  # BinSearch switches to linear search if the numer of elements to sorted
  # is less than 1 << LIN_BITS (i.e. 2^LIN_BITS - 1)
  LIN_BITS = 6

  module Methods
    # Binary search for the first elem that is leq elem in this array in the range
    # (low..high-1)
    #
    # By default, <=> is used to compare elements.  Alternatively, a comparator
    # may be specified as block parameter
    #
    # The array is expected to be sorted in ascending order.
    #
    # @param [Object] elem elem to search for
    # @param [Fixnum] low lower bound (inclusive)
    # @param [Fixnum] high upper bound (inclusive, -1 for last element)
    # @return [Fixnum] index of first occurence leq than elem in self, or -1 if not found
    #
    def bin_search_asc(elem, low = 0, high = -1)
      high = size - 1 if high < 0
      if block_given?
        then bin_search_desc(elem, low, high, +1) { |a, b| yield a, b }
        else bin_search_desc(elem, low, high, +1) { |a, b| a <=> b } end
    end

    # Binary search for the first elem that is leq elem in this array in the range
    # (low..high-1)
    #
    # By default, <=> is used to compare elements.  Alternatively, a comparator
    # may be specified as block parameter
    #
    # The array is expected to be sorted in descending order.
    #
    # @param [Object] elem elem to search for
    # @param [Fixnum] low lower bound (inclusive)
    # @param [Fixnum] high upper bound (inclusive, -1 for last element)
    # @return [Fixnum] index of first occurence leq than elem in self, or -1 if not found
    #
    def bin_search_desc(elem, low = 0, high = -1)
      high = size - 1 if high < 0
      if block_given?
        then bin_search_desc(elem, low, high, -1) { |a, b| yield a, b }
        else bin_search_desc(elem, low, high, -1) { |a, b| a <=> b } end
    end

    # Binary search for the first elem that is leq elem in this array in the range
    # (low..high-1)
    #
    # Elements are compared using <=> after mapping them using the provided block
    #
    # The array is expected to be sorted in ascending order.
    #
    # @param [Object] elem elem to search for
    # @param [Fixnum] low lower bound (inclusive)
    # @param [Fixnum] high upper bound (inclusive, -1 for last element)
    # @return [Fixnum] index of first occurence leq than elem in self, or -1 if not found
    #
    def bin_search_asc_by(elem, low = 0, high = -1)
      high = size - 1 if high < 0
      bin_search_asc(elem, low, high, +1) { |a, b| (yield a) <=> (yield b) }
    end

    # Binary search for the first elem that is leq elem in this array in the range
    # (low..high-1)
    #
    # Elements are compared using <=> after mapping them using the provided block
    #
    # The array is expected to be sorted in descending order.
    #
    # @param [Object] elem elem to search for
    # @param [Fixnum] low lower bound (inclusive)
    # @param [Fixnum] high upper bound (inclusive, -1 for last element)
    # @return [Fixnum] index of first occurence leq than elem in self, or -1 if not found
    #
    def bin_search_desc_by(elem, low = 0, high = -1)
      high = size - 1 if high < 0
      bin_search_desc(elem, low, high, -1) { |a, b| (yield a) <=> (yield b) }
    end

    # Binary search for the first elem that is leq elem in this array in the range
    # (low..high-1)
    #
    # A comparator must be specified as block parameter
    #
    # The array is expected to be sorted in ascending order if dir is +1 (default),
    # and in descending order if dir is -1
    #
    # @param [Object] elem elem to search for
    # @param [Fixnum] low lower bound (inclusive)
    # @param [Fixnum] high upper bound (inclusive, -1 for last element)
    # @param [Fixnum] dir direction, +1 for ascending, -1 for descending order
    # @return [Fixnum] index of first occurence leq than elem in self, or -1 if not found
    #
    def bin_search(elem, low, high, dir = +1)
      raise ArgumentError, 'Invalid direction (must be +1 or -1)' if dir.abs != 1
      last = -1
      sz = high - low
      if sz >> LIN_BITS
        # On 2012 cpus, linear search is slightly faster than binary search
        # if the number of searched elements is in the range of 50-100 elts
        cur_index = low
        while cur_index <= high
          cmp = yield elem, self[cur_index]
          # TODO Just compare the signbits if this can be done quicker
          if cmp == dir
            then cur_index += 1
            else return cur_index end
        end
        return -1
      else
        # Classic binary search
        while low <= high
          mid_index = low + (sz >> 1)
          cmp = yield elem, self[mid_index]
          # TODO Just compare the signbits if this can be done quicker
          if cmp == dir
            low  = mid_index + 1
          else
            last = mid_index
            high = mid_index - 1
          end
          sz -= 1
        end
        return last
      end
    end

  end # module Methods

end # module BinSeach

class ::Array
  include ::BinSearch::Methods
end
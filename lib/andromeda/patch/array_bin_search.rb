module BinSearch

  LIN_BITS = 6

  module Methods
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
        then _bin_search_desc(elem, low, high) { |a, b| yield a, b }
        else _bin_search_desc(elem, low, high) { |a, b| a <=> b } end
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
      _bin_search_desc(elem, low, high) { |a, b| (yield a) <=> (yield b) }
    end

    private

    def _bin_search_desc(elem, low, high)
      last = -1
      # On 2012 cpus, linear search is slightly faster than binary search
      # if the number of searched elements is in the range of 50-100 elts
      sz = high - low
      if (sz >> LIN_BITS)
        cur_index = low
        while cur_index <= high
          cmp = yield elem, self[cur_index]
          if cmp == -1
            then cur_index += 1
            else return cur_index end
        end
        return -1
      else
        while low <= high
          mid_index = low + (sz >> 1)
          cmp = yield elem, self[mid_index]
          if cmp == -1
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
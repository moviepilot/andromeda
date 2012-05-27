module BinSearch

  # BinSearch switches to linear search if the numer of elements to sorted
  # is less than 1 << LIN_BITS (i.e. 2^LIN_BITS - 1)
  LIN_BITS = 6

  MODES         = [ :asc, :desc, :asc_leq, :desc_geq, :asc_eq, :desc_eq ]
  MODE_IS_ASC   = [ :asc, :asc_eq, :asc_leq ]
  MODE_IS_DESC  = [ :desc, :desc_eq, :desc_geq ]
  MODE_CHECK_EQ = [ :asc_eq, :desc_eq ]

  module Methods

    # Binary search for the first elem in this array matching according to mode in the range
    # (low..high-1)
    #
    # By default, <=> is used to compare elements.  Alternatively, a comparator
    # may be specified as block parameter
    #
    # The supported modes are
    # * :asc - array is expected to be sorted in ascending order, first geq elem is matched
    # * :asc_eq - array expected to be sorted in ascending order, first eq elem is matched
    # * :desc - array is expected to be sorted in descending order, first leq elem is matched
    # * :desc_eq - array is expected to be sorted in descending order, first eq elem is matched
    #
    # @param [Object] elem elem to search for
    # @param [Fixnum] low lower bound (inclusive)
    # @param [Fixnum] high upper bound (inclusive, -1 for last element)
    # @param [:asc, :desc, :asc_eq, :desc_eq] matching mode
    # @return [Fixnum] index of first matching elem in self, or -1 if not found
    #
    def bin_index(elem, mode, low = 0, high = -1)
      dir      = if ::BinSearch::MODE_IS_ASC.include?(mode) then +1 else -1 end
      check_eq = ::BinSearch::MODE_CHECK_EQ.include?(mode)
      high     = size - 1 if high < 0
      if block_given?
        then _bin_index(elem, low, high, dir, check_eq) { |a, b| yield a, b }
        else _bin_index(elem, low, high, dir, check_eq) { |a, b| a <=> b } end
    end

    # Binary search for the first elem in this array matching according to mode in the range
    # (low..high-1)
    #
    # Elements are compared using <=> after mapping them using the provided block
    #
    # The supported modes are
    # * :asc - array is expected to be sorted in ascending order, first geq elem is matched
    # * :asc_eq - array expected to be sorted in ascending order, first eq elem is matched
    # * :desc - array is expected to be sorted in descending order, first leq elem is matched
    # * :desc_eq - array is expected to be sorted in descending order, first eq elem is matched
    #
    # @param [Object] elem elem to search for
    # @param [Fixnum] low lower bound (inclusive)
    # @param [Fixnum] high upper bound (inclusive, -1 for last element)
    # @param [:asc, :desc, :asc_eq, :desc_eq] matching mode
    # @return [Fixnum] index of first matching elem in self, or -1 if not found
    #
    def bin_index_by(elem, mode, low = 0, high = -1)
      dir      = if ::BinSearch::MODE_IS_ASC.include?(mode) then +1 else -1 end
      check_eq = ::BinSearch::MODE_CHECK_EQ.include?(mode)
      high     = size - 1 if high < 0
      _bin_index(elem, low, high, dir, check_eq) { |a, b| (yield a) <=> (yield b) }
    end

    # Binary search for the first elem in this array matching according to mode in the range
    # (low..high-1)
    #
    # By default, <=> is used to compare elements.  Alternatively, a comparator
    # may be specified as block parameter
    #
    # The supported modes are
    # * :asc - array is expected to be sorted in ascending order, first geq elem is matched
    # * :asc_eq - array expected to be sorted in ascending order, first eq elem is matched
    # * :desc - array is expected to be sorted in descending order, first leq elem is matched
    # * :desc_eq - array is expected to be sorted in descending order, first eq elem is matched
    #
    # @param [Object] elem elem to search for
    # @param [Fixnum] low lower bound (inclusive)
    # @param [Fixnum] high upper bound (inclusive, nil for last element)
    # @param [:asc, :desc, :asc_eq, :desc_eq] matching mode
    # @return [Object] first matching elem in self, or nil if not found
    #
    def bin_search(elem, mode, low = 0, high = -1)
      dir      = if ::BinSearch::MODE_IS_ASC.include?(mode) then +1 else -1 end
      check_eq = ::BinSearch::MODE_CHECK_EQ.include?(mode)
      high     = size - 1 if high < 0
      if block_given?
        then _bin_search(elem, low, high, dir, check_eq) { |a, b| yield a, b }
        else _bin_search(elem, low, high, dir, check_eq) { |a, b| a <=> b } end
    end

    # Binary search for the first elem in this array matching according to mode in the range
    # (low..high-1)
    #
    # Elements are compared using <=> after mapping them using the provided block
    #
    # The supported modes are
    # * :asc - array is expected to be sorted in ascending order, first geq elem is matched
    # * :asc_eq - array expected to be sorted in ascending order, first eq elem is matched
    # * :desc - array is expected to be sorted in descending order, first leq elem is matched
    # * :desc_eq - array is expected to be sorted in descending order, first eq elem is matched
    #
    # @param [Object] elem elem to search for
    # @param [Fixnum] low lower bound (inclusive)
    # @param [Fixnum] high upper bound (inclusive, nil for last element)
    # @param [:asc, :desc, :asc_eq, :desc_eq] matching mode
    # @return [Object] first matching elem in self, or nil if not found
    #
    def bin_search_by(elem, mode, low = 0, high = -1)
      dir      = if ::BinSearch::MODE_IS_ASC.include?(mode) then +1 else -1 end
      check_eq = ::BinSearch::MODE_CHECK_EQ.include?(mode)
      high     = size - 1 if high < 0
      _bin_seach(elem, low, high, dir, check_eq) { |a, b| (yield a) <=> (yield b) }
    end

    # Binary search for the first elem in this array matching according to mode in the range
    # (low..high-1)
    #
    # By default, <=> is used to compare elements.  Alternatively, a comparator
    # may be specified as block parameter
    #
    # The supported modes are
    # * :asc - array is expected to be sorted in ascending order, first geq elem is matched
    # * :asc_eq - array expected to be sorted in ascending order, first eq elem is matched
    # * :desc - array is expected to be sorted in descending order, first leq elem is matched
    # * :desc_eq - array is expected to be sorted in descending order, first eq elem is matched
    #
    # @param [Object] elem elem to search for
    # @param [Fixnum] low lower bound (inclusive)
    # @param [Fixnum] high upper bound (inclusive, nil for last element)
    # @param [:asc, :desc, :asc_eq, :desc_eq] matching mode
    # @return [Array] [index, first matching elem] in self, or nil if not found
    #
    def bin_assoc(elem, mode, low = 0, high = -1)
      dir      = if ::BinSearch::MODE_IS_ASC.include?(mode) then +1 else -1 end
      check_eq = ::BinSearch::MODE_CHECK_EQ.include?(mode)
      high     = size - 1 if high < 0
      if block_given?
        then _bin_assoc(elem, low, high, dir, check_eq) { |a, b| yield a, b }
        else _bin_assoc(elem, low, high, dir, check_eq) { |a, b| a <=> b } end
    end

    # Binary search for the first elem in this array matching according to mode in the range
    # (low..high-1)
    #
    # Elements are compared using <=> after mapping them using the provided block
    #
    # The supported modes are
    # * :asc - array is expected to be sorted in ascending order, first geq elem is matched
    # * :asc_eq - array expected to be sorted in ascending order, first eq elem is matched
    # * :desc - array is expected to be sorted in descending order, first leq elem is matched
    # * :desc_eq - array is expected to be sorted in descending order, first eq elem is matched
    #
    # @param [Object] elem elem to search for
    # @param [Fixnum] low lower bound (inclusive)
    # @param [Fixnum] high upper bound (inclusive, nil for last element)
    # @param [:asc, :desc, :asc_eq, :desc_eq] matching mode
    # @return [Array] [index, first matching elem] in self, or nil if not found
    #
    def bin_assoc_by(elem, mode, low = 0, high = -1)
      dir      = if ::BinSearch::MODE_IS_ASC.include?(mode) then +1 else -1 end
      check_eq = ::BinSearch::MODE_CHECK_EQ.include?(mode)
      high     = size - 1 if high < 0
      _bin_assoc(elem, low, high, dir, check_eq) { |a, b| (yield a) <=> (yield b) }
    end

    private

    def _bin_index(elem, low, high, dir, check_eq)
      sz   = high - low
      if (sz >> LIN_BITS).zero?
        # On 2012 cpus, linear search is slightly faster than binary search
        # if the number of searched elements is in the range of 50-100 elts
        cur_index = low
        while cur_index <= high
          cur = self[cur_index]
          cmp = yield elem, cur
          if cmp == dir
            then cur_index += 1
            else return (if (check_eq && cmp.nonzero?) then -1 else cur_index end) end
        end
        return -1
      else
        # Classic binary search
        cmp_ = 0
        last = -1
        while low <= high
          mid_index = low + (sz >> 1)
          mid = self[mid_index]
          cmp = yield elem, mid
          if cmp == dir
            low  = mid_index + 1
          else
            cmp_ = cmp
            last = mid_index
            high = mid_index - 1
          end
          sz -= 1
        end
        return (if (check_eq && cmp_.nonzero?) then -1 else last end)
      end
    end

    def _bin_search(elem, low, high, dir, check_eq)
      sz   = high - low
      cur  = nil
      if (sz >> LIN_BITS).zero?
        # On 2012 cpus, linear search is slightly faster than binary search
        # if the number of searched elements is in the range of 50-100 elts
        cur_index = low
        while cur_index <= high
          cur = self[cur_index]
          cmp = yield elem, cur
          if cmp == dir
            then cur_index += 1
            else return (if (check_eq && cmp.nonzero?) then nil else cur end) end
        end
        return nil
      else
        # Classic binary search
        cmp_ = 0
        last = -1
        while low <= high
          mid_index = low + (sz >> 1)
          mid = self[mid_index]
          cmp = yield elem, mid
          if cmp == dir
            low  = mid_index + 1
          else
            cmp_ = cmp
            cur  = mid
            last = mid_index
            high = mid_index - 1
          end
          sz -= 1
        end
        return (if (check_eq && cmp_.nonzero?) then nil else cur end)
      end
    end

    def _bin_assoc(elem, low, high, dir, check_eq)
      sz   = high - low
      cur  = nil
      if (sz >> LIN_BITS).zero?
        # On 2012 cpus, linear search is slightly faster than binary search
        # if the number of searched elements is in the range of 50-100 elts
        cur_index = low
        while cur_index <= high
          cur = self[cur_index]
          cmp = yield elem, cur
          if cmp == dir
            cur_index += 1
          else
            return (if (!cur || (check_eq && cmp.nonzero?)) then nil else [cur_index, cur] end)
          end
        end
        return nil
      else
        # Classic binary search
        cmp_ = 0
        last = -1
        while low <= high
          mid_index = low + (sz >> 1)
          mid = self[mid_index]
          cmp = yield elem, mid
          if cmp == dir
            low  = mid_index + 1
          else
            cmp_ = cmp
            cur  = mid
            last = mid_index
            high = mid_index - 1
          end
          sz -= 1
        end
        return (if (!cur || (check_eq && cmp_.nonzero?)) then nil else [last, cur] end)
      end
    end

  end # module Methods

end # module BinSeach

class ::Array
  include ::BinSearch::Methods
end
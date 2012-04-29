module Andromeda

  class ::Object

    def identical_copy
      case clone_to_copy?
      when false then self
      when true then clone
      else clone rescue self end
    end

    def clone_to_copy? ; cloneable? end
    def cloneable? ; nil end
  end

  class ::NilClass
    def cloneable? ; false end
  end

  class ::FalseClass
    def cloneable? ; false end
  end

  class ::FalseClass
    def cloneable? ; false end
  end

  class ::Numeric
    def cloneable? ; false end
  end

  class ::Symbol
    def cloneable? ; false end
  end

  class ::Thread
    def cloneable? ; false end
  end

  class ::Regexp
    def cloneable? ; false end
  end

end
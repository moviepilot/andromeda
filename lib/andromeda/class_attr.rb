module Andromeda

	module ClassAttr

    protected

    def get_attr_set(var_name, inherit = true)
      s = if instance_variable_defined?(var_name)
            then instance_variable_get(var_name)
            else Set.new end
      if inherit
        c = self
        while (c = c.superclass)
          s = s.union c.destinations(false) rescue s
        end
      end
      s
    end

    def name_attr_set(var_name, *names)
      name_set = names.to_set
      dest_set = get_attr_set var_name, false
      instance_variable_set var_name, dest_set.union(name_set)
    end
	end

end
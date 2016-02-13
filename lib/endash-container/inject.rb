module Injections
  def _inline_injections_
    @_inline_injections_ ||= []
  end

  def inject(*types_map)
    @_inline_injections_ = types_map
  end
end

Class.send(:include, Injections)
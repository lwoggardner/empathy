class SpecGuard
  alias :implementation_orig :implementation?
  def implementation?(*args)
    args.any? { |name| name == :empathy } || implementation_orig(*args)
  end

  def standard?
   implementation?(:ruby) && !implementation?(:empathy)
  end
end

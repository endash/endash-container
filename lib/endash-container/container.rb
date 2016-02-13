class Container
  class Injection
    attr_reader :dependencies, :block

    def initialize(*dependencies, &block)
      @dependencies = dependencies
      @block = block
    end
  end

  Token = Struct.new(:token)
  Value = Struct.new(:value)

  def self.token(token)
    Token.new(token)
  end

  def self.value(value)
    Value.new(value)
  end

  NoSuchToken = Class.new(StandardError)
  TokenNotResolved = Class.new(StandardError)

  def initialize parent = {}, injections = {}
    unless parent.is_a?(Container)
      injections = parent
      parent = nil
    end

    @parent = parent
    @injections = normalize_injections(injections)
    @injections_cache = {}
    @resolved = {}
    @flatten_cache = {}
    @has_cache = {}
  end

  def has? token
    @has_cache[token] ||= @injections.has_key?(token) || (token.is_a?(String) && !!find_string_token(token))
  end

  def get token
    lookup(token)
  end

  protected

  def find_string_token(token)
    @injections[token] || @injections[token.to_sym] || find_nested_token(token)
  end

  def find_nested_token(token)
    token_tree = token.split(".")
    token_tree.reduce(@injections) do |current_level, token|
      current_level && (current_level[token] || current_level[token.to_sym])
    end
  rescue
    nil
  end

  def normalize_injections(injections_hash)
    injections_hash.each_with_object({}) do |(key, injection), h|
      case injection
      when Hash
        h[key] = normalize_injections(injection)
      else
        h[key] = normalize_injection(injection)
      end
    end
  end

  def lookup(token)
    @resolved[token] ||= resolve_token(token)
  end

  def resolve_token(token)
    unless injection = get_injection(token)
      raise NoSuchToken, "Token did not resolve to an injection: #{token}"
    end

    unless resolved = resolve(token, injection)
      raise TokenNotResolved, "Token resolved to an injection but did not resolve to a value: #{token}"
    end

    resolved
  end

  def get_injection(token)
    @injections_cache[token] ||= begin
      if token.is_a?(String)
        injection = find_string_token(token)
      else
        injection = @injections[token]
      end

      if injection.nil? && @parent
        parent_injection = @parent.get_injection(token)
      end

      injection || parent_injection || normalize_injection(token)
    end
  end

  def normalize_injection(injection)
    case injection
    when Injection
      injection
    when Token
      Injection.new(injection.token) { |injection| injection }
    when Value
      Injection.new { injection.value }
    when Array
      case injection.first
      when Class
        Injection.new(*injection.drop(1)) { |*injections| injection.first.new(*injections) }
      when Proc
        Injection.new(*injection.drop(1)) { |*injections| injection.first.call(*injections) }
      end
    when Class
      if injection.respond_to?(:_inline_injections_)
        inline_injections = injection._inline_injections_
      else
        inline_injections = []
      end

      Injection.new(*inline_injections) { |*injections| injection.new(*injections) }
    when Proc
      Injection.new { |*injections| injection.call(*injections) }
    when nil
      nil
    else
      Injection.new { injection }
    end
  end

  def resolve(token, injection)
    flattened = flatten(token, injection)

    if has?(token) || flattened.keys.any? { |token| has?(token) } || !@parent
      resolved_dependencies = injection.dependencies.map do |dep|
        lookup(dep)
      end

      injection.block.call(*resolved_dependencies)
    elsif @parent
      @parent.lookup(token)
    end
  end

  def flatten(token, injection)
    @flatten_cache[token] ||= injection.dependencies.each_with_object({}) do |nested_token, h|
      nested_injection = get_injection(nested_token)
      h[nested_token] = nested_injection
      h.merge!(flatten(nested_token, nested_injection))
    end
  end
end

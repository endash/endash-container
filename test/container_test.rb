require 'endash-container'
require 'minitest/autorun'

class TestContainer < Minitest::Test
  def test_has_with_string
    container = Container.new({"foo" => "Bar"})

    assert container.has?("foo")
  end

  def test_has_with_symbol
    container = Container.new({"foo" => "Bar"})

    assert container.has?(:foo)
  end

  def test_has_with_nested_token
    container = Container.new({bar: {"foo" => "Bar"}})

    assert container.has?("bar.foo")
  end

  def test_has_with_literal_dot_token
    container = Container.new({"bar.foo" => "Bar"})

    assert container.has?("bar.foo")
  end

  def test_has_with_literal_dot_token_as_symbol
    container = Container.new({:"bar.foo" => "Bar"})

    assert container.has?("bar.foo")
  end

  def test_empty_container_instantiates_classes
    fooClass = Class.new
    container = Container.new()
    assert_instance_of fooClass, container.get(fooClass)
  end

  def test_token_injection_forwards_to_specified_token
    fooClass = Class.new
    container = Container.new({foo: Container.token(fooClass)})

    assert_equal container.get("foo"), container.get(fooClass)
  end

  def test_value_injection_returns_the_value
    container = Container.new({foo: "Bar"})

    assert_equal "Bar", container.get("foo")
  end

  def test_value_injection_of_class_returns_the_class
    fooClass = Class.new
    container = Container.new({foo: Container.value(fooClass)})

    assert_equal fooClass, container.get("foo")
  end

  def test_class_injection_instantiates_the_class
    barClass = Class.new
    container = Container.new({foo: barClass})

    assert_instance_of barClass, container.get("foo")
  end

  def test_proc_injection_calls_the_proc
    container = Container.new({foo: ->() { "Baz" }})

    assert_equal "Baz", container.get("foo")
  end

  def test_class_with_a_dependency_is_injected
    barClass = Struct.new(:foo)

    container = Container.new({foo: "Foo", bar: [barClass, "foo"]})
    assert_equal "Foo", container.get("bar").foo
  end

  def test_proc_with_a_dependency_is_called_with_dependency
    bar = ->(foo) { [foo] }
    fooClass = Class.new

    container = Container.new({foo: fooClass, bar: [bar, "foo"]})
    assert_instance_of fooClass, container.get("bar").first
  end

  def test_injection_object_calls_the_block
    container = Container.new({foo: Container::Injection.new() { "Bar" }})

    assert_equal "Bar", container.get("foo")
  end

  def test_injection_object_with_a_dependency_is_called_with_dependency
    barClass = Class.new
    foo = Container::Injection.new("bar") { |bar| bar }

    container = Container.new({bar: barClass, foo: foo})
    assert_instance_of barClass, container.get("foo")
  end

  def test_multiple_lookups_return_same_instance
    fooClass = Class.new
    barClass = Struct.new(:foo)

    container = Container.new({foo: fooClass, bar: [barClass, "foo"]})
    foo = container.get("foo")
    bar = container.get("bar")

    assert_same foo, container.get("foo")
    assert_same foo, bar.foo
    assert_same bar, container.get("bar")
    assert_same foo, container.get("bar").foo
  end
end

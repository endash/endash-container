require 'endash-container'
require 'minitest/autorun'

class TestChildContainers < Minitest::Test
  def test_that_injections_defined_on_the_child_are_resolved_on_the_child
    fooClass = Class.new
    bazClass = Class.new
    barClass = Struct.new(:foo)

    container = Container.new({foo: fooClass, bar: [barClass, :foo]})
    child_container = Container.new(container, {foo: bazClass})

    assert_instance_of bazClass, child_container.get(:bar).foo
  end

  def test_that_injections_defined_on_the_parent_continue_to_resolve_on_the_parent_if_called_on_the_parent
    fooClass = Class.new
    bazClass = Class.new
    barClass = Struct.new(:foo)

    container = Container.new({foo: fooClass, bar: [barClass, :foo]})
    child_container = Container.new(container, {foo: bazClass})

    child_container.get(:bar)

    assert_instance_of fooClass, container.get(:bar).foo
  end

  def test_that_parent_and_child_share_the_same_instance_if_not_explicitly_overriden
    fooClass = Class.new
    bazClass = Class.new
    foobazClass = Class.new
    barClass = Struct.new(:foo, :baz)

    container = Container.new({foo: fooClass, baz: bazClass, bar: [barClass, :foo, :baz]})
    child_container = Container.new(container, {baz: foobazClass})

    child_container.get(:bar)

    assert_same child_container.get(:foo), container.get(:foo)
    assert_same child_container.get(:bar).foo, container.get(:foo)
  end
end
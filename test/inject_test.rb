require 'endash-container'
require 'endash-container/inject'
require 'minitest/autorun'

class TestInjections < Minitest::Test
  Bar = Class.new
  Foobar = Class.new

  def test_basic_class_injection
    fooClass = Class.new do
      attr_reader :bar

      inject(Bar)
      def initialize bar
        @bar = bar
      end
    end

    container = Container.new()

    foo = container.get(fooClass)
    assert_instance_of Bar, foo.bar
  end

  def test_mapped_class_injection
    fooClass = Class.new do
      attr_reader :bar

      inject(Bar)
      def initialize bar
        @bar = bar
      end
    end

    container = Container.new({Bar => Foobar})

    foo = container.get(fooClass)
    assert_instance_of Foobar, foo.bar
  end

  def test_injected_token
    fooClass = Class.new do
      attr_reader :bar

      inject("barToken")
      def initialize bar
        @bar = bar
      end
    end

    container = Container.new(barToken: Bar)

    foo = container.get(fooClass)
    assert_instance_of Bar, foo.bar
  end
end
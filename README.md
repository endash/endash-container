# endash-container

[![Code Climate](https://codeclimate.com/github/endash/endash-container/badges/gpa.svg)](https://codeclimate.com/github/endash/endash-container)

This gem provides a `Container` class, a simple containerized approach to dependency injection for Ruby. This is currently considered unstable software under active development and all features and APIs are subject to change.

### A container? This isn't C#, we don't need no stinkin' container.

Indeed, we don't "need" a container anymore than we "need" any other pattern that helps improve our code design. My personal motivation in using containers is to enable my classes to be as loosely coupled as possible, and to simplify instantiating complex graphs of classes and their dependencies. Like any pattern, you may find it has a "sweet spot" beyond which there are diminishing returns to scale, but on the whole the container/DI combo can enable real improvements in code design over Ruby that is supposedly more "idiomatic".

### That sounds like gibberish, give me a concrete example.

Suppose you have three classes: An `Automobile` needs a `Powertrain`, which in turn needs an `Engine`. A very naive initial implementation might look like:

```ruby
class Automobile
  def initialize
    @powertrain = Powertrain.new
  end
end

class Powertrain
  def initialize
    @engine = Engine.new
  end
end

class Engine
end
```

This is no good. We've separated our concerns nicely, of course, so it isn't a total loss, but we've hardcoded all of our dependencies. A second try might look more like:

```ruby
class Automobile
  def initialize(powertrain)
    @powertrain = powertrain
  end
end

class Powertrain
  def initialize(engine)
    @engine = engine
  end
end

class Engine
end
```

This is constructor-based dependency injection. And—so far as dependency injection in Ruby goes—this is *just fine*. You don't "need" anything more to do DI. Where you hit a bump in the road is when you want to construct usable objects out of these classes:

```ruby
car = Automobile.new(Powertrain.new(Engine.new))
```

Imagine this littered all over your code, wherever you instantiate a class. Of course, you can partially clean this up with various factory methods or such. No matter which way you slice that bacon, though, you end up with a bunch of code somewhere with knowledge of how these classes tie together, and you probably still are left with a handful of tightly defined, hard-coded combinations. A container helps solve the glue-code and hard-code problems by: (1) Maintaining a dependency graph, so it can handle finding or instantiating all necessary dependencies on demand and (2) Allowing an implementation to be dynamically substituted for a given dependency, at any point in the graph.

## Using `Container`

`Container` is initialized with a hash of injection mappings. Regardless of its mappings—or lack thereof—a container will instantiate classes when it encounters them:

```ruby
Bar = Class.new
container = Container.new({})

container.get(Bar)
 => #<Bar:0x007fb21a117b68>
```

An injection mapping is a normal key,value pair. The key is the token, and can be a string/symbol, class, or other object. `Container` supports five different kinds of mappings as part of the provided hash:

### Value

The simplest injection mapping associates a value with a token. Whenever the token is requested, either directly or as a dependency, the value will be returned untouched.

```ruby
container = Container.new({foo: "bar"})

container.get("foo")
 => "bar"
```

Note: If you want to map to a `Class`, `Proc`, `Hash`, or `Array` as a value then you'll need to wrap it in `Container.value`, otherwise it will be treated as a more complex mapping.

```ruby
Foo = Class.new
container = Container.new({foo: Container.value(Foo)})

container.get("foo") == Foo
 => true
```

### Token

Using `Container.token` you can forward one token to another. In this way you can ensure multiple mappings result in the same resolved value. For instance, without using `token`, you might run into the following behaviour.

```ruby
Bar = Class.new
Foo = Class.new
container = Container.new({Foo => Bar})

container.get(Foo) == container.get(Bar)
 => false
```

This happens because there are two mappings here: `{Foo => Bar}` and an implicit `{Bar => Bar}`. We can avoid that, if desired, as follows.

```ruby
Bar = Class.new
Foo = Class.new
container = Container.new({Foo => Container.token(Bar)})

container.get(Foo) == container.get(Bar)
 => true
```

### Class

Any kind of token, including another `Class`, can be mapped to a `Class`. The class will be instantiated only once for a given token (but more than once if more than one token maps to the class—see Token above.)

```ruby
Bar = Class.new
container = Container.new({foo: Bar})

bar1 = container.get("foo")
 => #<Bar:0x007fb21a104fb8>

bar2 = container.get("foo")
 => #<Bar:0x007fb21a104fb8>

bar1 == bar2
 => true
```

A class can be mapped to another class.

```ruby
Bar = Class.new
Foo = Class.new
container = Container.new({Foo => Bar})

container.get(Foo)
 => #<Bar:0x007fb21a0bc790>
```

### Proc

A proc can be provided to determine behaviour at runtime. A proc mapping will be called once, and then cached.

```ruby
container = Container.new({foo: ->{ rand }})

container.get("foo")
 => 0.8936167495016784
container.get("foo")
 => 0.8936167495016784
```

If you'd like the proc to be callable multiple times then wrap it in `Container.value` and register it as a value mapping.

### Array

A `Class` or `Proc` mapping may be nested as the first item in an array, in which case the subsequent items will be treated as tokens to be looked up recursively and injected into the `Class` or `Proc`.

```ruby
Foo = Class.new do
  attr_reader :bar

  def initialize(bar)
    @bar = bar
  end
end

Bar = Class.new
container = Container.new({foo: [Foo, Bar]})

container.get("foo").bar
 => #<Bar:0x007fb21a898b80>
```

Note that any classes provided as dependencies in the array will be treated as tokens, and will be instantiated only once per token, as usual.


## Parent containers

A `Container` can be initialized with a parent `Container` as the first argument.

```ruby
parent = Container.new({foo: ->{ rand }})
child = Container.new(parent)
```

Mappings defined on the parent that are not occluded in any way by the child (either redefined directly, or a dependency, or a dependency's dependency, etc) will resolve on the parent normally.

```ruby
parent.get("foo")
 => 0.23449670698965586

child.get("foo")
 => 0.23449670698965586
```

Mappings will resolve at the highest level they can. If you override the dependencies for a mapping, that mapping will resolve on the child container, but the dependencies themselves may continue to resolve on the parent. Conversely, overriding a single "deep" dependency could result in a cascade of tokens resolving a-new on the child container, but any "sibling" dependencies will be unaffected.

```ruby
Foo = Class.new do
  attr_reader :foobar, :bar

  def initialize(foobar, bar)
    @foobar = foobar
    @bar = bar
  end
end
Bar = Class.new
Baz = Class.new
Foobar = Class.new

parent = Container.new({foo: [Foo, Foobar, "bar"], bar: Bar})
child = Container.new(parent, {bar: Baz})

parentFoo = parent.get("foo")
 => #<Foo:0x007fb21a878f88>

childFoo = child.get("foo")
 => #<Foo:0x007fb21a8608e8>

parentFoo == childFoo
 => false

parentFoo.foobar == childFoo.foobar
 => true
```

What's going on here: `"foo"` in both cases maps to `Foo`, with two dependencies: `Foobar` and `"bar"`. The parent and child containers have different mappings for `"bar"`, so the requested token will resolve separately. Since `Foobar` is unchanged, `Foobar` will continue to resolve on the parent container for both instances of `Foo`.

## Nested tokens

You can pass a nested hash to `Container` to organize mappings under high-level common keys.

```ruby
container = Container.new({repository: {user: UserRepository, post: PostRepository}})

user_repo = container.get("repository.user")
 => #<UserRepository:0x007fb21a8bb3b0>
```

## Inline injections

Specifying all the dependencies on the container directly can be laborious and brittle. By (optionally) requiring `endash-container/inject`, classes will gain an `inject` class method. Calling `inject` with an array of tokens inside the class definition block will result in those dependencies being picked up by the container when it encounters that class.

```ruby
Bar = Class.new
Foo = Class.new do
  attr_reader :bar

  inject(Bar)
  def initialize(bar)
    @bar = bar
  end
end

container = Container.new({})

container.get(Bar) == container.get(Foo).bar
```

Note that `Bar` in `inject(Bar)` is a token, not a mapping itself, so it doesn't need to be wrapped in `Container.token` to ensure a single instance.

## Default inline injections

You can also specify a generic token as an inline injection, mapped to a more specific default token that can be overridden on the container. For instance, you may want to have something akin to interface tokens:

```ruby
ISerializationStrategy = {}.freeze
IMessageHandler = {}.freeze
```

and use them to auto-inject your implementations:

```ruby
class Foo
	inject(IMessageHandler => AppMessageHandler)
	def initialize(message_handler)
		@message_handler = message_handler
	end
end
```

If an `IMessageHandler` is registered on the container, this is equivalent to `inject(IMessageHandler)` and whatever injection is registered on the container will be used. If not, then this is equivalent to `inject(AppMessageHandler)`. As above, if `AppMessageHandler` is registered on the container, then that injection is used. Otherwise, the default behaviour for an unregistered class token remains auto-instantiation.

$LOAD_PATH.unshift 'lib'
require "endash-container/version"

Gem::Specification.new do |s|
  s.name              = "endash-container"
  s.version           = Container::VERSION
  s.date              = "2012-02-12"
  s.summary           = "Simple dependency injection & container for Ruby"
  s.homepage          = "http://github.com/endash/endash-container"
  s.email             = "christopher.swasey@gmail.com"
  s.authors           = [ "Christopher Swasey" ]
  s.has_rdoc          = false
  s.files             = %w( README.md Gemfile Rakefile LICENSE )
  s.files            += Dir.glob("lib/**/*")
  s.files            += Dir.glob("test/**/*")
  s.description       = "Simple dependency injection & container for Ruby"
end

Gem::Specification.new do |s|
  s.name      = 'rethinkdb'
  s.version   = '1.6.0.0'
  s.summary   = 'This package provides the Ruby driver library for the RethinkDB database server.'
  s.author    = 'RethinkDB Inc.'
  s.email     = 'bugs@rethinkdb.com'
  s.homepage  = 'http://rethinkdb.com'
  s.license   = 'Apache-2'
  s.files     = Dir['lib/*.rb']

  s.add_runtime_dependency "json"
  s.add_runtime_dependency "ruby_protobuf"
end


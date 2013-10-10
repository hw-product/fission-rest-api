$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'fission-rest-api/version'
Gem::Specification.new do |s|
  s.name = 'fission-rest-api'
  s.version = Fission::RestApi::VERSION.version
  s.summary = 'Fission REST API'
  s.author = 'Heavywater'
  s.email = 'fission@hw-ops.com'
  s.homepage = 'http://github.com/heavywater/fission-rest-api'
  s.description = 'Fission REST API'
  s.require_path = 'lib'
#  s.add_dependency 'fission'
  s.add_dependency 'carnivore'
  s.add_dependency 'carnivore-http'
  s.files = Dir['**/*']
end

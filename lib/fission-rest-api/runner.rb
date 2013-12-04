require 'carnivore'
require 'carnivore-http'
require 'carnivore-http/point_builder'

Carnivore.configure do
  Carnivore::Source.build(
    :type => :http_endpoints,
    :args => {
      :name => :rest_api,
      :bind => Carnivore::Config.get(:fission, :rest_api, :setup, :bind) || '0.0.0.0',
      :port => Carnivore::Config.get(:fission, :rest_api, :setup, :port) || 9876
    }
  )
end

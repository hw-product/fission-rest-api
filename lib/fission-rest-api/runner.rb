require 'carnivore'
require 'carnivore-http'
require 'carnivore-http/point_builder'

Dir.glob(File.join(File.dirname(__FILE__), 'api', '*.rb')).each do |path|
  require "fission-rest-api/api/#{File.basename(path).sub('.rb', '')}"
end

Carnivore.configure do

  Carnivore::Source.build(
    :type => :http_endpoints,
    :args => {
      :name => :fission_rest_api,
      :bind => Carnivore::Config.get(:rest_api, :setup, :bind) || '0.0.0.0',
      :port => Carnivore::Config.get(:rest_api, :setup, :port) || 9876
    }
  )

end

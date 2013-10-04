require 'carnivore/runner'

Carnivore.configure do

  Fission::RestApi.workers = Carnivore::Config.get(:workers, :rest_api)

  http = Carnivore::Source.build(
    :type => :http,
    :args => {
      :bind => Carnivore::Config.get(:rest_api, :setup, :bind) || '0.0.0.0',
      :port => Carnivore::Config.get(:rest_api, :setup, :port) || 9876
    }
  )

  http.add_callback(:rest_api, Fission::RestApi)

end

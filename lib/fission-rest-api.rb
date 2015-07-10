require 'fission'
require 'fission-rest-api/version'

module Fission
  module RestApi
    autoload :Repository, 'fission-rest-api/repository'
    autoload :Helpers, 'fission-rest-api/helpers'
  end
end

require 'fission-rest-api/repository'

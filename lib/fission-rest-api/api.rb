require 'carnivore/callback'
require 'fission-rest-api/builder'

module Fission
  module RestApi
    class Api < Carnivore::Callback

      def setup
        apis = Array(
          Carnivore::Config.get(:rest_api, :enabled_apis)
        ).flatten.compact.map(&:to_s)
        Dir.glob(File.join(File.dirname(__FILE__), 'apis/*.rb')).each do |api_file|
          f_name = File.basename(api_file).sub('.rb', '')
          next if apis.include?(f_name)
          require "fission-rest-api/apis/#{f_name}"
        end
        @str_endpoints, @regexp_endpoints = Builder.instance.endpoints
      end

      def execute(message)
        m = message[:message]
        result = process(
          m[:request].method.to_s.downcase.to_sym,
          m[:request].url,
          m[:request],
          m[:connection]
        )
        unless(result)
          con.respond(:not_found, 'Invalid request!')
        end
      end

      def process(*args)
        process_str_endpoints(*args) || process_regexp_endpoints(*args)
      end

      def process_str_endpoints(type, string, request, connection)
        if(@str_endpoints[type])
          @str_endpoints[type].each do |k,v|
            if(k == string)
              v.run(request, connection)
              return true
            end
          end
        end
        false
      end

      def process_regexp_endpoints(type, string, request, connection)
        if(@regexp_endpoints[type])
          @regexp_endpoints[type].each do |k,v|
            unless(res = string.scan(k).empty?)
              if(res.first.is_a?(Array))
                v.run(request, connection, res)
              else
                v.run(request, connection)
              end
              return true
            end
          end
        end
        false
      end
    end
  end
end

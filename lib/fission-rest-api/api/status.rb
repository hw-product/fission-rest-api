require 'fission'

Carnivore::Http::PointBuilder.define do
  get '/status' do |*_|
    msg.confirm!(:response_body => 'OK!')
  end
end

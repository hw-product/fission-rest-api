require 'fission'

Carnivore::Http::PointBuilder.define do
  get '/status' do |msg, *_|
    msg.confirm!(:response_body => 'OK!')
  end
end

require_relative '../../spec_helper'
require 'json'

class BaseResource
  include PCO::API::Resource

  self.base_path = '/people/v2'
end

class Person < BaseResource
  self.path = 'people'
  self.per_page = 100
end

class Address < BaseResource
  self.path = 'addresses'
end

describe PCO::API::Resource do
  before do
    BaseResource.connection = PCO::API.new(basic_auth_token: 'token', basic_auth_secret: 'secret')
  end

  describe '.all' do
    let(:response1) do
      {
        data: [
          {
            type: 'Person',
            id: '1',
            attributes: {
              first_name: 'Tim',
              last_name: 'Morgan'
            },
            relationships: {
              addresses: {
                data: [
                  {
                    type: 'Address',
                    'id': '1'
                  }
                ]
              }
            }
          }
        ],
        included: [
          {
            type: 'Address',
            id: '1',
            attributes: {
              street: '123 N Main',
              city: 'Tulsa',
              state: 'OK',
              zip: '74120'
            }
          }
        ],
        meta: {
          next: {
            offset: 1
          }
        }
      }
    end

    let(:response2) do
      {
        data: [
          {
            type: 'Person',
            id: '2',
            attributes: {
              first_name: 'Jennie',
              last_name: 'Morgan'
            },
            relationships: {
              addresses: {
                data: [
                  {
                    type: 'Address',
                    'id': '2'
                  }
                ]
              }
            }
          }
        ],
        included: [
          {
            type: 'Address',
            id: '2',
            attributes: {
              street: '123 N Main',
              city: 'Tulsa',
              state: 'OK',
              zip: '74120'
            }
          }
        ]
      }
    end

    before do
      stub_request(
        :get,
        'https://api.planningcenteronline.com/people/v2/people?per_page=100&include=addresses'
      ).to_return(
        status: 200,
        body: response1.to_json,
        headers: { 'Content-Type' => 'application/vnd.api+json' }
      )
      stub_request(
        :get,
        'https://api.planningcenteronline.com/people/v2/people?per_page=100&offset=1&include=addresses'
      ).to_return(
        status: 200,
        body: response2.to_json,
        headers: { 'Content-Type' => 'application/vnd.api+json' }
      )
    end

    it 'returns an array of Person objects' do
      results = Person.all(include: { 'addresses' => Address }).to_a
      expect(results).to eq(
        [
          Person.new(
            id: 1,
            first_name: 'Tim',
            last_name: 'Morgan'
          ),
          Person.new(
            id: 2,
            first_name: 'Jennie',
            last_name: 'Morgan'
          )
        ]
      )
      expect(results.first.addresses).to eq(
        [
          Address.new(
            id: 1,
            street: '123 N Main',
            city: 'Tulsa',
            state: 'OK',
            zip: '74120'
          )
        ]
      )
    end
  end
end

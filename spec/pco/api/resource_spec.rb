require_relative '../../spec_helper'
require 'json'

class BaseResource
  include PCO::API::Resource

  self.base_path = '/people/v2'
end

class Person < BaseResource
  self.path = 'people'
end

class Address < BaseResource
  self.path = 'addresses'
end

describe PCO::API::Resource do
  let(:response1) do
    {
      data: [
        {
          type: 'Person',
          id: '1',
          attributes: {
            first_name: 'Tim',
            last_name: 'Morgan'
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
          }
        }
      ]
    }
  end

  before do
    BaseResource.connection = PCO::API.new(basic_auth_token: 'token', basic_auth_secret: 'secret')
    stub_request(
      :get,
      'https://api.planningcenteronline.com/people/v2/people?per_page=0'
    ).to_return(
      status: 200,
      body: { meta: { total_count: 2, count: 0 } }.to_json,
      headers: { 'Content-Type' => 'application/vnd.api+json' }
    )
    stub_request(
      :get,
      'https://api.planningcenteronline.com/people/v2/people'
    ).to_return(
      status: 200,
      body: response1.to_json,
      headers: { 'Content-Type' => 'application/vnd.api+json' }
    )
    stub_request(
      :get,
      'https://api.planningcenteronline.com/people/v2/people?offset=1'
    ).to_return(
      status: 200,
      body: response2.to_json,
      headers: { 'Content-Type' => 'application/vnd.api+json' }
    )
  end

  describe '.all' do
    it 'returns a CollectionProxy' do
      proxy = Person.all
      expect(proxy).to be_a(PCO::API::CollectionProxy)
    end
  end

  describe '.per_page' do
    it 'returns a CollectionProxy' do
      proxy = Person.per_page(100)
      expect(proxy).to be_a(PCO::API::CollectionProxy)
    end
  end

  describe '.includes' do
    it 'returns a CollectionProxy' do
      proxy = Person.includes('addresses' => Address)
      expect(proxy).to be_a(PCO::API::CollectionProxy)
    end
  end

  describe '.first' do
    it 'returns the first Person' do
      person = Person.first
      expect(person).to eq(
        Person.new(
          id: 1,
          first_name: 'Tim',
          last_name: 'Morgan'
        )
      )
    end
  end

  describe '.last' do
    it 'returns the last Person' do
      person = Person.last
      expect(person).to eq(
        Person.new(
          id: 2,
          first_name: 'Jennie',
          last_name: 'Morgan'
        )
      )
    end
  end
end

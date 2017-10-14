require_relative '../../spec_helper'
require 'json'
require 'ostruct'

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

describe PCO::API::CollectionProxy do
  let(:connection) do
    PCO::API.new(basic_auth_token: 'token', basic_auth_secret: 'secret')
  end

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
        total_count: 2,
        count: 1,
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
      ],
      meta: {
        total_count: 2,
        count: 1
      }
    }
  end

  subject do
    described_class.new(
      connection: connection,
      path: 'people/v2/people',
      klass: Person,
      params: {},
    )
  end

  describe '#all' do
    before do
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

    it 'returns an array of objects' do
      results = subject.to_a
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
    end

    context 'when a rate limit error occurs' do
      before do
        stub_request(
          :get,
          'https://api.planningcenteronline.com/people/v2/people?per_page=100'
        ).to_return(
          [
            {
              status: 429,
              body: {
                errors: [
                  { code: '429', detail: 'Rate limit exceeded: 116 of 100 requests per 20 seconds' }
                ]
              }.to_json,
              headers: {
                'Content-Type'                  => 'application/vnd.api+json',
                'X-PCO-API-Request-Rate-Count'  => '116',
                'X-PCO-API-Request-Rate-Limit'  => '100',
                'X-PCO-API-Request-Rate-Period' => '20 seconds',
                'Retry-After'                   => '1'
              }
            },
            {
              status: 200,
              body: response1.to_json,
              headers: { 'Content-Type' => 'application/vnd.api+json' }
            }
          ]
        )
      end

      subject do
        described_class.new(
          connection: connection,
          path: 'people/v2/people',
          klass: Person,
          params: { per_page: 100 }
        )
      end

      it 'sleeps and then retries' do
        expect(subject).to receive(:sleep).with(1)
        subject.first
      end
    end
  end

  describe '#each' do
    before do
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

    it 'yields objects' do
      results = []
      subject.each do |object|
        results << object
      end
      expect(results.size).to eq(2)
    end
  end

  describe '#first' do
    before do
      stub_request(
        :get,
        'https://api.planningcenteronline.com/people/v2/people'
      ).to_return(
        status: 200,
        body: response1.to_json,
        headers: { 'Content-Type' => 'application/vnd.api+json' }
      )
    end

    it 'returns the first object' do
      result = subject.first
      expect(result).to eq(
        Person.new(
          id: 1,
          first_name: 'Tim',
          last_name: 'Morgan'
        )
      )
    end
  end

  describe '#last' do
    let(:meta_response) do
      {
        data: [],
        meta: {
          total_count: 2,
          count: 0
        }
      }
    end

    before do
      stub_request(
        :get,
        'https://api.planningcenteronline.com/people/v2/people?per_page=0'
      ).to_return(
        status: 200,
        body: meta_response.to_json,
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

    it 'returns the last object' do
      result = subject.last
      expect(result).to eq(
        Person.new(
          id: 2,
          first_name: 'Jennie',
          last_name: 'Morgan'
        )
      )
    end
  end

  describe '#per_page' do
    before do
      stub_request(
        :get,
        'https://api.planningcenteronline.com/people/v2/people?per_page=100'
      ).to_return(
        status: 200,
        body: response1.to_json,
        headers: { 'Content-Type' => 'application/vnd.api+json' }
      )
      stub_request(
        :get,
        'https://api.planningcenteronline.com/people/v2/people?per_page=100&offset=1'
      ).to_return(
        status: 200,
        body: response2.to_json,
        headers: { 'Content-Type' => 'application/vnd.api+json' }
      )
    end

    it 'returns self' do
      proxy = subject.per_page(100)
      expect(proxy).to be_a(described_class)
    end

    describe 'the returned proxy' do
      before do
        stub_request(
          :get,
          'https://api.planningcenteronline.com/people/v2/people?per_page=100'
        ).to_return(
          status: 200,
          body: response1.to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' }
        )
      end

      it 'builds objects with included resources' do
        result = subject.per_page(100).first
        expect(result).to be_a(Person)
      end
    end
  end

  describe '#includes' do
    it 'returns self' do
      proxy = subject.includes('addresses' => Address)
      expect(proxy).to be_a(described_class)
    end

    describe 'the returned proxy' do
      before do
        stub_request(
          :get,
          'https://api.planningcenteronline.com/people/v2/people?include=addresses'
        ).to_return(
          status: 200,
          body: response1.to_json,
          headers: { 'Content-Type' => 'application/vnd.api+json' }
        )
      end

      it 'builds objects with included resources' do
        result = subject.includes('addresses' => Address).first
        expect(result).to be_a(Person)
        expect(result.addresses).to eq(
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
end

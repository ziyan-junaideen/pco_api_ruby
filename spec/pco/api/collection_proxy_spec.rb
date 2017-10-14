require_relative '../../spec_helper'
require 'json'
require 'ostruct'

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

  subject do
    described_class.new(
      connection: connection,
      path: 'people/v2/people',
      params: {},
      wrap_proc: ->(record, _included) { record }
    )
  end

  describe '#all' do
    it 'returns an array of objects' do
      results = subject.to_a
      expect(results).to match(
        [
          include(
            'type' => 'Person',
            'id' => '1',
            'attributes' => {
              'first_name' => 'Tim',
              'last_name' => 'Morgan'
            }
          ),
          include(
            'type' => 'Person',
            'id' => '2',
            'attributes' => {
              'first_name' => 'Jennie',
              'last_name' => 'Morgan'
            }
          )
        ]
      )
    end
  end

  describe '#each' do
    it 'yields objects' do
      results = []
      subject.each do |object|
        results << object
      end
      expect(results.size).to eq(2)
    end
  end

  describe '#first' do
    it 'returns the first object' do
      result = subject.first
      expect(result).to include(
        'type' => 'Person',
        'id' => '1',
        'attributes' => {
          'first_name' => 'Tim',
          'last_name' => 'Morgan'
        }
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
    end

    it 'returns the last object' do
      result = subject.last
      expect(result).to include(
        'type' => 'Person',
        'id' => '2',
        'attributes' => {
          'first_name' => 'Jennie',
          'last_name' => 'Morgan'
        }
      )
    end
  end
end

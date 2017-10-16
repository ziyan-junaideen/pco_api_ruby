require_relative './collection_proxy'

module PCO
  module API
    module Resource
      module ClassMethods
        attr_writer :connection, :base_path, :path

        def connection
          @connection || (superclass.respond_to?(:connection) ? superclass.connection : nil)
        end

        def base_path
          @base_path || (superclass.respond_to?(:base_path) ? superclass.base_path : nil)
        end

        def path
          @path || (superclass.respond_to?(:path) ? superclass.path : nil)
        end

        def all
          CollectionProxy.new(
            connection: connection,
            path: full_path,
            klass: self,
            params: {}
          )
        end

        def find(id)
          all.find(id)
        rescue PCO::API::Errors::NotFound
          raise Resource::RecordNotFound
        end

        def find_by(conditions)
          all.find_by(conditions)
        end

        def first
          all.first
        end

        def last
          all.last
        end

        def per_page(count)
          all.per_page(count)
        end

        def where(conditions)
          all.where(conditions)
        end

        def order(*attrs)
          all.order(*attrs)
        end

        def includes(mappings)
          all.includes(mappings)
        end

        def build_object(record, included: {}, include_mapping: {})
          object = new(record['attributes'].update('id' => record['id'].to_i))
          object.relationships = record['relationships']
          object.included = build_included(
            record['relationships'],
            included: included,
            include_mapping: include_mapping
          )
          object
        end

        def build_included(relationships, included: {}, include_mapping: {})
          hash = {}
          (relationships || {}).each do |rel, data|
            if data['data'].is_a?(Array)
              hash[rel] = build_included_array(rel, data['data'], included: included, include_mapping: include_mapping)
            else
              hash[rel] = build_included_single(rel, data['data'], included: included, include_mapping: include_mapping)
            end
          end
          hash
        end

        def build_included_array(rel, data, included:, include_mapping:)
          return [] if data.empty?
          included_of_type = included.select { |rec| rec['type'] == data.first['type'] }
          records = included_of_type.select do |rec|
            data.map { |r| r['id'] }.include?(rec['id'])
          end
          records.map do |record|
            next unless include_mapping[rel]
            include_mapping[rel].build_object(
              record,
              included: included,
              include_mapping: include_mapping
            )
          end.compact
        end

        def build_included_single(rel, data, included:, include_mapping:)
          return unless include_mapping[rel] && data
          record = included.detect { |rec| rec['type'] == data['type'] && rec['id'] == data['id'] }
          include_mapping[rel].build_object(
            record,
            included: included,
            include_mapping: include_mapping
          )
        end

        def full_path
          [base_path, path].compact.join('/').gsub(%r{//}, '/').sub(%r{^/}, '')
        end
      end

      class RecordNotFound < StandardError; end

      def self.included(base)
        base.extend(ClassMethods)
      end

      def initialize(attributes = {})
        attributes = Hash[attributes.map { |k, v| [k.to_s, v] }]
        @included = attributes.delete('included') || {}
        @attributes = attributes
      end

      attr_accessor :attributes, :included, :relationships

      def method_missing(name, *args)
        if name.to_s =~ /=$/
          name = name.to_s.sub(/=$/, '')
          @attributes[name] = args.first
        elsif @included.key?(name.to_s)
          @included[name.to_s]
        elsif @attributes.key?(name.to_s)
          @attributes[name.to_s]
        else
          super
        end
      end

      def respond_to_missing?(name, include_private = false)
        @included.key?(name.to_s) || @attributes.key?(name.to_s) || super
      end

      def ==(other)
        self.class.name == other.class.name && attributes == other.attributes
      end
    end
  end
end

module PCO
  module API
    class CollectionProxy
      def initialize(connection:, path:, params:, wrap_proc:)
        @connection = connection
        @path = path
        @params = params
        @wrap_proc = wrap_proc
        reset
      end

      attr_reader :connection, :path, :wrap_proc

      def each
        loop do
          fetch_next if more?
          record = consume_and_transform
          break unless record
          yield record
        end
      end

      def to_a
        reset
        array = []
        each do |object|
          array << object
        end
        array
      end

      def first
        reset
        fetch_next
        consume_and_transform
      end

      def last
        reset
        meta = fetch_meta
        @offset = meta['total_count'] - 1
        fetch_next
        record = @response['data'].last
        return unless record
        transform(record)
      end

      private

      def consume_and_transform
        record = @response['data'].shift
        return unless record
        transform(record)
      end

      def transform(record)
        wrap_proc.call(record, @response['included'])
      end

      def reset
        @offset = nil
      end

      def more?
        return true unless @response
        @response['data'].empty? &&
          @response.fetch('meta', {}).fetch('next', {})['offset']
      end

      def params
        @params.update(
          offset: @offset
        ).reject { |_, v| v.nil? }
      end

      def fetch_next
        @response = connection[path].get(params)
        @offset = @offset.to_i + 1
      rescue PCO::API::Errors::TooManyRequests => e
        sleep e.retry_after
        retry
      end

      def fetch_meta
        connection[path].get(params.update(per_page: 0))['meta']
      end
    end
  end
end

module GoogleContacts
  class Wrapper
    attr_reader :consumer

    CONTACTS_BATCH = "http://www.google.com/m8/feeds/contacts/default/full/batch".freeze
    GROUPS_BATCH   = "http://www.google.com/m8/feeds/groups/default/full/batch".freeze

    # Proxies for crud
    attr_reader :contacts
    attr_reader :groups

    def initialize(consumer)
      @consumer = consumer

      @contacts = CollectionProxy.new(self, 'contacts')
      @groups   = CollectionProxy.new(self, 'groups')
    end

    def get(url, options = {})
      query = options.map { |k,v| "#{k}=#{v}" }.join('&')
      url += "?#{query}" if query.size > 0

      body = consumer.get(url).body
      Nokogiri::XML.parse body
    end

    def post(url, body)
      consumer.post(url, body, 'Content-Type' => 'application/atom+xml')
    end

    def batch(options = {}, &blk)
      raise "Nesting of calls to batch is not allowed" if @batching
      @batching = true
      @batch ||= []

      yield(blk)
      @batching = false

      # create documents to be flushed
      documents = @batch.each_slice(100).map do |chunk|
        batch_document(chunk)
      end
      @batch.clear

      if options[:return_documents]
        documents
      else
        documents.each do |doc|
          flush_batch(doc)
        end
      end
    end

    def find(what, options = {}, &blk)
      xml = get("http://www.google.com/m8/feeds/#{what}/default/full", options)
      xml.xpath('/xmlns:feed/xmlns:entry').map(&blk)
    end

    def save(instance)
      entry = instance.entry_for_batch(instance.new? ? :insert : :update)
      append_to_batch(entry)
    end

    private

    def append_to_batch(entry)
      if @batching
        if @batch.present?
          # puts @batch.last.a
          # puts @batch.last.at('./category').inspect
          batch_term = @batch.last.at('./category')['term']
          entry_term =       entry.at('./category')['term']
          raise "Cannot mix Contact and Group in one batch" if batch_term != entry_term
        end

        @batch << entry
      else
        batch do
          @batch << entry
        end
      end
    end

    # Use the <category/> tag of the first entry to find out
    # which type we're flushing
    def flush_batch(document)
      url = case document.at('./xmlns:entry[1]/xmlns:category')['term']
      when /#contact$/i
        CONTACTS_BATCH
      when /#group$/i
        GROUPS_BATCH
      else
        raise "Unable to determine type for batch"
      end
      post(url, document.to_xml)
    end

    def batch_document(*operations)
      batch_feed = Base.feed_for_batch
      operations.flatten.each do |operation|
        batch_feed << operation
      end
      batch_feed
    end

    class CollectionProxy
      def initialize(wrapper, collection)
        @wrapper    = wrapper
        @collection = collection
        @klass      = collection.singularize.camelcase.constantize
      end

      # :what - all, ID, whatever, currently unused
      def find(what, options = {})
        @wrapper.find(@collection, options) do |entry|
          @klass.new(@wrapper, entry)
        end
      end

      def build(attributes = {})
        @klass.new(@wrapper)
      end

    end # class CollectionProxy
  end # class Wrapper
end # module GoogleContacts

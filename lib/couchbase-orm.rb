# frozen_string_literal: true, encoding: ASCII-8BIT

require 'mt-libcouchbase'
MTLibcouchbase.autoload(:QueryN1QL, 'ext/query_n1ql')

module CouchbaseOrm
    autoload :Error,       'couchbase-orm/error'
    autoload :Connection,  'couchbase-orm/connection'
    autoload :IdGenerator, 'couchbase-orm/id_generator'
    autoload :Base,        'couchbase-orm/base'

    def self.try_load(id)
        result = nil
        was_array = id.is_a?(Array)
        if was_array && id.length == 1
            id = id.first
        end
        result = id.respond_to?(:cas) ? id : CouchbaseOrm::Base.bucket.get(id, quiet: true, extended: true)
        if was_array
            result = Array.wrap(result)
        end
        if result && result.is_a?(Array)
            return result.map { |r| self.try_load(r) }.compact
        end

        if result && result.value.is_a?(Hash) && result.value[:type]
            ddoc = result.value[:type]
            ::CouchbaseOrm::Base.descendants.each do |model|
                if model.design_document == ddoc
                    return model.new(result)
                end
            end
        end
        nil
    end

    def self.logger
        @@logger ||= defined?(Rails) ? Rails.logger : Logger.new(STDOUT)
    end

    def self.logger=(logger)
        @@logger = logger
    end
end

# Provide Boolean conversion function
# See: http://www.virtuouscode.com/2012/05/07/a-ruby-conversion-idiom/
module Kernel
    private

    def Boolean(value)
        case value
        when String, Symbol
            case value.to_s.strip.downcase
            when 'true'
                return true
            when 'false'
                return false
            end
        when Integer
            return value != 0
        when false, nil
            return false
        when true
            return true
        end

        raise ArgumentError, "invalid value for Boolean(): \"#{value.inspect}\""
    end
end
class Boolean < TrueClass; end

# If we are using Rails then we will include the Couchbase railtie.
if defined?(Rails)
    require 'couchbase-orm/railtie'
end


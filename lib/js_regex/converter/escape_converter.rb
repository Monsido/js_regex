# frozen_string_literal: true

require_relative 'base'
require_relative 'literal_converter'

class JsRegex
  module Converter
    #
    # Template class implementation.
    #
    class EscapeConverter < JsRegex::Converter::Base
      private

      def convert_data
        case subtype
        when :backslash,
             :bol,
             :carriage,
             :codepoint,
             :dot,
             :eol,
             :form_feed,
             :hex,
             :interval_close,
             :interval_open,
             :newline,
             :octal,
             :one_or_more,
             :set_close,
             :set_open,
             :tab,
             :vertical_tab,
             :zero_or_more,
             :zero_or_one
          pass_through
        when :literal
          LiteralConverter.convert(data, self)
        else
          # Backspace, Bell, HexWide, Control, Meta, MetaControl, ...
          warn_of_unsupported_feature
        end
      end
    end
  end
end

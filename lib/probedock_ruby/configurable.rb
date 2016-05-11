module ProbeDockProbe
  module Configurable
    def self.included mod
      mod.extend ClassMethods
    end

    def initialize attrs = {}
      set_configurable_attrs(nil_attrs.merge(attrs.kind_of?(Hash) ? attrs : {}))
    end

    def empty?
      self.class.configurable_attrs.all? do |attr|
        value = send(attr)
        value.nil? || value.respond_to?(:empty?) && value.empty?
      end
    end

    def update attrs = {}
      set_configurable_attrs(attrs)
    end

    def clear
      self.class.configurable_attrs.each do |attr|
        value = send(attr)
        if value.kind_of?(Configurable)
          value.clear
        else
          send("#{attr}=", nil)
        end
      end
    end

    def to_h
      self.class.configurable_attrs.inject({}) do |memo,attr|

        value = send(attr)
        if value.kind_of?(Configurable)
          memo[attr] = value.to_h
        elsif !attr_empty?(attr)
          memo[attr] = value
        end

        memo
      end
    end

    private

    def attr_empty?(attr)
      value = send(attr)
      value.nil? || value.respond_to?(:empty?) && value.empty?
    end

    def nil_attrs
      self.class.configurable_attrs.inject({}) do |memo,attr|
        memo[attr] = nil
        memo
      end
    end

    def set_boolean attr, value
      instance_variable_set("@#{attr}", value.nil? ? nil : !!value)
    end

    def set_integer attr, value
      instance_variable_set("@#{attr}", value.nil? ? nil : value.to_s.to_i)
    end

    def set_string attr, value
      instance_variable_set("@#{attr}", value.nil? ? nil : value.to_s)
    end

    def set_string_array attr, value
      instance_variable_set("@#{attr}", wrap(value).compact.collect(&:to_s))
    end

    def set_configurable klass, attr, value
      variable = "@#{attr}"
      if configurable = instance_variable_get(variable)
        configurable.update value
      else
        instance_variable_set("@#{attr}", klass.new(value))
      end
    end

    def set_configurable_attrs attrs = {}
      return self unless attrs.kind_of?(Hash)

      self.class.configurable_attrs.each do |attr|
        send("#{attr}=", attrs[attr]) if attrs.key?(attr)
      end

      self
    end

    def wrap a
      a.kind_of?(Array) ? a : [ a ]
    end

    module ClassMethods
      def configurable attr_definitions = {}

        @configurable_attrs = attr_definitions.keys

        attr_definitions.each do |attr,type|

          setter = if type.kind_of?(Class) && type.included_modules.include?(Configurable)
            :configurable
          elsif type.kind_of?(Symbol)
            type
          else
            raise "Unsupported type of configurable attribute #{type.inspect}; must be either a symbol or a configurable class"
          end

          attr_reader attr

          define_method "#{attr}=" do |value|
            if setter == :configurable
              send :set_configurable, type, attr, value
            else
              send "set_#{type}", attr, value
            end
          end
        end
      end

      def configurable_attrs *attrs
        @configurable_attrs || []
      end
    end
  end
end

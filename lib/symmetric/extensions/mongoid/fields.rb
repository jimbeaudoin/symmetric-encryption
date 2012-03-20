# Extensions to the mongoid Document model to support field encryption
# per the attr_encrypted model
#
#
#   #TODO initialize, create
#
module Mongoid
  module Fields
    module ClassMethods
      # Example:
      #
      #  class Person
      #    include Mongoid::Document
      #    include Symmetric::Encryption::Mongoid
      #
      #    field :name,                             :type => String
      #    field :encrypted_social_security_number, :type => String, :encrypted => true, :decrypt_as => :social_security_number
      #    field :age,                              :type => Integer
      #
      #  end
      #
      # The above document results in the following document in the Mongo collection 'persons':
      # {
      #   "name" : "Joe",
      #   "encrypted_social_security_number" : "...",
      #   "age"  : 21
      # }
      #
      # Symmetric Encryption creates the getters and setters to be able to work with the field
      # in it's unencrypted form. For example
      #
      # Example:
      #   person = Person.where(:encrypted_social_security_number => '...').first
      #
      #   puts "Decrypted Social Security Number is: #{person.social_security_number}"
      #
      #   # Or is the same as
      #   puts "Decrypted Social Security Number is: #{Symmetric::Encryption.decrypt(person.encrypted_social_security_number)}"
      #
      #   # Sets the encrypted_social_security_number to encrypted version
      #   person.social_security_number = "123456789"
      #
      #   # Or, is equivalent to:
      #   person.social_security_number = Symmetric::Encryption.encrypt("123456789")
      #
      #
      # Note: Unlike attr_encrypted finders must use the encrypted field name
      #   For Example this is NOT valid:
      #     person = Person.where(:social_security_number => '123456789').first
      #
      # Defines all the fields that are accessible on the Document
      # For each field that is defined, a getter and setter will be
      # added as an instance method to the Document.
      #
      # @example Define a field.
      #   field :score, :type => Integer, :default => 0
      #
      # @param [ Symbol ] name The name of the field.
      # @param [ Hash ] options The options to pass to the field.
      #
      # @option options [ Class ] :type The type of the field.
      # @option options [ String ] :label The label for the field.
      # @option options [ Boolean ] :encryption If the field contains encrypted data.
      # @option options [ Symbol ] :decrypt_as Name of the getters and setters to generate to access the decrypted value of this field.
      # @option options [ Object, Proc ] :default The field's default
      #
      # @return [ Field ] The generated field
      def field_with_symmetric_encryption(field_name, options={})
        if options.delete(:encrypted) == true
          decrypt_as = options.delete(:decrypt_as)
          unless decrypt_as
            raise "Symmetric::Encryption for Mongoid. When encryption is enabled for a field it must either start with 'encrypted_' or the option :decrypt must be supplied" unless field_name.to_s.start_with?('encrypted_')
            decrypt_as = field_name.to_s['encrypted_'.length..-1]
          end

          # Store Intended data type for this field, but we store it as a String
          underlying_type = options[:type]
          options[:type] = String

          raise "Symmetric::Encryption for Mongoid currently only supports :type => String" unless underlying_type == String

          # #TODO Need to do type conversions. Currently only support String

          # Generate getter and setter methods
          class_eval(<<-EOS, __FILE__, __LINE__ + 1)
            # Set the un-encrypted bank account number
            # Also updates the encrypted field with the encrypted value
            def #{decrypt_as}=(value)
              @stored_#{field_name} = Symmetric::Encryption.encrypt(value)
              self.#{field_name} = @stored_#{field_name}
              @#{decrypt_as} = value
            end

            # Returns the decrypted value for the encrypted field
            # The decrypted value is cached and is only decrypted if the encrypted value has changed
            # If this method is not called, then the encrypted value is never decrypted
            def #{decrypt_as}
              if @stored_#{field_name} != self.#{field_name}
                @#{decrypt_as} = Symmetric::Encryption.decrypt(self.#{field_name})
                @stored_#{field_name} = self.#{field_name}
              end
              @#{decrypt_as}
            end
          EOS
        end

        # Pass on to the regular Mongoid field method
        field_without_symmetric_encryption(field_name, options)
      end
      alias_method_chain :field, :symmetric_encryption

    end

  end
end

# frozen_string_literal: true

module LspData
  # convert a OIT person hash into alma xml
  class OitPersonToAlma
    attr_reader :person, :xml

    # @param xml [XMLBuilder] builder to insert the person into
    # @param person [Hash] oit hash of a person
    def initialize(person:, xml:)
      @person = person
      @xml = xml
    end

    def alma_person
      xml.user do
        create_status
        create_user_statistics
        create_user_info
        create_contact_information
        create_identifiers
      end
    end

    private

    def user_info
      {
        'expiry_date' => person['PATRON_EXPIRATION_DATE'],
        'purge_date' => person['PATRON_PURGE_DATE'],
        'user_group' => person['PVPATRONGROUP'],
        'primary_id' => person['EMPLID'],
        'first_name' => person['PRF_OR_PRI_FIRST_NAM'], # _NAM is not a typo
        'last_name' => person['PRF_OR_PRI_LAST_NAME'],
        'middle_name' => person['PRF_OR_PRI_MIDDLE_NAME']
      }
    end

    def create_user_info
      user_info.each do |key, value|
        xml << "<#{key}>#{value}<\/#{key}>" if value
      end
    end

    def create_status
      status_flag = person['ELIGIBLE_INELIGIBLE'].to_s
      return if status_flag.empty?

      if status_flag == 'E' && not_a_retiree?
        xml.status 'ACTIVE'
      else
        xml.status 'INACTIVE'
      end
    end

    def create_user_statistics
      statistic_category = person['PVSTATCATEGORY'].to_s
      return if statistic_category.empty?

      xml.user_statistics do
        xml.user_statistic(segment_type: 'External') do
          xml.statistic_category(desc: statistic_category) { xml.text statistic_category }
        end
      end
    end

    def create_contact_information
      return if person['CAMP_EMAIL'].to_s.empty? && person['HOME_EMAIL'].to_s.empty?

      xml.contact_info do
        create_addresses
        create_emails
      end
    end

    def create_addresses
      xml.addresses do
        if %w[UGRD SENR].include?(person['PVPATRONGROUP'])
          create_ugrd_senr_addresses
        else
          create_other_addresses
        end
      end
    end

    def create_ugrd_senr_addresses
      create_address(type: 'school',
                     preferred: true)
      create_address(type: 'home',
                     preferred: person['DORM_ADDRESS1'].to_s.empty?)
    end

    def create_other_addresses
      create_address(type: 'work',
                     preferred: true)
      create_address(type: 'home',
                     preferred: person['CAMP_ADDRESS1'].to_s.empty?)
    end

    def create_emails
      xml.emails do
        camp_email = person['CAMP_EMAIL'].to_s
        if camp_email.empty?
          create_email(email: person['HOME_EMAIL'].to_s, preferred: false, type: 'personal',
                       description: 'Personal')
        else
          create_email(email: camp_email, preferred: true, type: 'work',
                       description: 'Work')
        end
      end
    end

    def create_email(email:, preferred:, type:, description:)
      xml.email(preferred:, segment_type: 'External') do
        xml.email_address email
        xml.email_types do
          xml.email_type(desc: description) { xml.text type }
        end
      end
    end

    def create_identifiers
      xml.user_identifiers do
        create_identifier(type: 'BARCODE', id: person['PU_BARCODE'], description: 'Barcode')
        create_identifier(type: 'NET_ID', id: person['CAMPUS_ID'], description: 'NetID')
      end
    end

    def create_identifier(type:, id:, description:)
      return if id.to_s.empty?

      xml.user_identifier(segment_type: 'External') do
        xml.value id
        xml.id_type(desc: description) { xml.text type }
        xml.status 'ACTIVE'
      end
    end

    def address_prefix(type)
      if type == 'school'
        'DORM'
      elsif type == 'home' && %w[UGRD SENR].include?(person['PVPATRONGROUP'])
        'PERM'
      elsif type == 'home'
        'HOME'
      elsif type == 'work'
        'CAMP'
      end
    end

    def address_info(address_prefix)
      {
        'line1' => person["#{address_prefix}_ADDRESS1"].to_s,
        'line2' => person["#{address_prefix}_ADDRESS2"],
        'line3' => person["#{address_prefix}_ADDRESS3"],
        'line4' => person["#{address_prefix}_ADDRESS4"],
        'city' => person["#{address_prefix}_CITY"],
        'state_province' => person["#{address_prefix}_STATE"],
        'postal_code' => person["#{address_prefix}_POSTAL"],
        'country' => person["#{address_prefix}_COUNTRY"]
      }
    end

    def create_address(type:, preferred:)
      address_prefix = address_prefix(type)
      return if person["#{address_prefix}_ADDRESS1"].empty?

      xml.address(preferred:, segment_type: 'External') do
        address_info(address_prefix).each do |key, value|
          xml << "<#{key}>#{value}<\/#{key}>" if value
        end
        xml.address_types do
          xml.address_type(desc: type) { xml.text type }
        end
      end
    end

    def not_a_retiree?
      person['VCURSTATUS'] != 'RETR'
    end
  end
end

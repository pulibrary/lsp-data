# frozen_string_literal: true

# convert a OIT person hash into alma xml
module LspData
  class OitPersonToAlma
    attr_reader :person, :xml

    # @param xml [XMLBuilder] builder to insert the person into
    # @param person [Hash] oit hash of a person
    def initialize(person:, xml:)
      @person = person
      @xml = xml
    end

    def convert
      xml.user do
        xml.expiry_date person["PATRON_EXPIRATION_DATE"] if person["PATRON_EXPIRATION_DATE"]
        xml.purge_date person["PATRON_PURGE_DATE"] if person["PATRON_PURGE_DATE"]
        create_status(status_flag: person["ELIGIBLE_INELIGIBLE"])
        create_user_statistics(statistic_category: person["PVSTATCATEGORY"])
        xml.user_group person["PVPATRONGROUP"]
        xml.primary_id person["EMPLID"]
        xml.first_name person["PRF_OR_PRI_FIRST_NAM"] if person["PRF_OR_PRI_FIRST_NAM"] # _NAM is not a typo
        xml.last_name person["PRF_OR_PRI_LAST_NAME"] if person["PRF_OR_PRI_LAST_NAME"]
        xml.middle_name person["PRF_OR_PRI_MIDDLE_NAME"] if person["PRF_OR_PRI_MIDDLE_NAME"]
        create_contact_information
        create_identifiers
      end
    end

    private

    def create_status(status_flag:)
      return if status_flag.to_s.empty?

      if status_flag == "E" && not_a_retiree?
        xml.status 'ACTIVE'
      else
        xml.status 'INACTIVE'
      end
    end

    def create_user_statistics(statistic_category:)
      return if statistic_category.to_s.empty?
      xml.user_statistics do
        xml.user_statistic(segment_type: "External") do
          xml.statistic_category(desc: statistic_category) { xml.text statistic_category }
        end
      end
    end

    def create_contact_information
      return if person["CAMP_EMAIL"].to_s.empty? && person["HOME_EMAIL"].to_s.empty?
      xml.contact_info do
        create_addresses
        create_emails
        # create_phone_numbers
      end
    end

    def create_addresses
      xml.addresses do
        if ["UGRD", "SENR"].include?(person["PVPATRONGROUP"])
          create_address(type: "school", preferred: true, line1: person["DORM_ADDRESS1"], line2: person["DORM_ADDRESS2"], line3: person["DORM_ADDRESS3"],
                         line4: person["DORM_ADDRESS4"], city: person["DORM_CITY"], state: person["DORM_STATE"], country: person["DORM_COUNTRY"], postal: person["DORM_postal"])
          create_address(type: "home", preferred: person["DORM_ADDRESS1"].to_s.empty?, line1: person["PERM_ADDRESS1"], line2: person["PERM_ADDRESS2"], line3: person["PERM_ADDRESS3"],
                         line4: person["PERM_ADDRESS4"], city: person["PERM_CITY"], state: person["PERM_STATE"], country: person["PERM_COUNTRY"], postal: person["PERM_postal"])
        else
          create_address(type: "work", preferred: true, line1: person["CAMP_ADDRESS1"], line2: person["CAMP_ADDRESS2"], line3: person["CAMP_ADDRESS3"],
                         line4: person["CAMP_ADDRESS4"], city: person["CAMP_CITY"], state: person["CAMP_STATE"], country: person["CAMP_COUNTRY"], postal: person["CAMP_postal"])
          create_address(type: "home", preferred: person["CAMP_ADDRESS1"].to_s.empty?, line1: person["HOME_ADDRESS1"], line2: person["HOME_ADDRESS2"], line3: person["HOME_ADDRESS3"],
                         line4: person["HOME_ADDRESS4"], city: person["HOME_CITY"], state: person["HOME_STATE"], country: person["HOME_COUNTRY"], postal: person["HOME_postal"])
        end
      end
    end

    def create_emails
      xml.emails do
        create_email(email: person["CAMP_EMAIL"], preferred: true, type: "work", description: "Work")
        create_email(email: person["HOME_EMAIL"], preferred: false, type: "personal", description: "Personal") if person["CAMP_EMAIL"].to_s.empty?
      end
    end

    def create_email(email:, preferred:, type:, description:)
      return if email.to_s.empty?
      xml.email(preferred:, segment_type: "External") do
        xml.email_address email
        # xml.email_address "stub@example.com"
        xml.email_types do
          xml.email_type(desc: description) { xml.text type }
        end
      end
    end

    def create_identifiers
      xml.user_identifiers do
        create_identifier(type: "BARCODE", id: person["PU_BARCODE"], description: 'Barcode') if person["PU_BARCODE"]
        create_identifier(type: "NET_ID", id: person["CAMPUS_ID"], description: 'NetID')
      end
    end

    def create_identifier(type:, id:, description:)
      return if id.to_s.empty?
      xml.user_identifier(segment_type: "External") do
        xml.value id
        xml.id_type(desc: description) { xml.text type }
        xml.status "ACTIVE"
      end
    end

    def create_address(type:, preferred:, line1:, line2:, line3:, line4:, city:, state:, country:, postal:)
      return if line1.to_s.empty?
      xml.address(preferred:, segment_type: "External") do
        xml.line1 line1
        xml.line2 line2 if line2
        xml.line3 line3 if line3
        xml.line4 line4 if line4
        xml.city city
        xml.state_province state
        xml.postal_code postal
        xml.country country
        xml.address_types do
          xml.address_type(desc: type) { xml.text type }
        end
      end
    end

    def not_a_retiree?
      person["VCURSTATUS"] != 'RETR'
    end
  end
end

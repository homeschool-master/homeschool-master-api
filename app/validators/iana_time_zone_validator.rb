# frozen_string_literal: true

# Validates that a value is a time zone identifier the IANA database knows,
# for example "America/New_York". Backed by TZInfo so the accepted set tracks
# the tzdata release the app ships with, rather than a list we have to
# maintain by hand.
class IanaTimeZoneValidator < ActiveModel::EachValidator
  def self.recognized?(identifier)
    TZInfo::Timezone.get(identifier.to_s)
    true
  rescue TZInfo::InvalidTimezoneIdentifier
    false
  end

  def validate_each(record, attribute, value)
    return if value.blank?
    return if self.class.recognized?(value)

    record.errors.add(attribute, options[:message] || 'is not a recognized IANA time zone')
  end
end

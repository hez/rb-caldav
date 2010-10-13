require 'lib/caldav.rb'

cal = Caldav.new( "caldavserver", 80, '/path/to/user/', 'user', 'password')
calendars = cal.calendars
p cal.report calendars['home'].first, Time.parse('20100101T000000')..Time.parse('20101231T000000')

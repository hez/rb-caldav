require 'lib/caldav.rb'

cal = Caldav.new( "icalserver", 80, '/path/to/user/', 'user', 'password')
calendars = cal.calendars
res = cal.todo calendars['home'].first

res.each { |todo| 
    p todo
}

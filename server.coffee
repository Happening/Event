App = require 'app'
Comments = require 'comments'
Db = require 'db'
Event = require 'event'
Timer = require 'timer'
{tr} = require 'i18n'

dayNames = [
	tr 'Sun'
	tr 'Mon'
	tr 'Tue'
	tr 'Wed'
	tr 'Thu'
	tr 'Fri'
	tr 'Sat'
]

monthNames = [
	tr 'Jan'
	tr 'Feb'
	tr 'Mar'
	tr 'Apr'
	tr 'May'
	tr 'Jun'
	tr 'Jul'
	tr 'Aug'
	tr 'Sep'
	tr 'Oct'
	tr 'Nov'
	tr 'Dec'
]

# convert daycount to 00:00 unix timestamp
dayToUnix = (day) ->
	d = new Date(day*864e5)
	offset = d.getTimezoneOffset() * 60 # seconds
	day * 86400 + offset

dayToString = (day) ->
	d = new Date(day*864e5)
	dayNames[d.getUTCDay()]+' '+d.getUTCDate()+' '+monthNames[d.getUTCMonth()]+' '+d.getUTCFullYear()

timeToString = (time) ->
	if !time?
		tr("None")
	else if time<0
		tr("All day")
	else
		minutes = (time/60)%60
		minutes = '0' + minutes if minutes.toString().length is 1
		(0|(time/3600))+':'+minutes

exports.onInstall = (config) !->
	log 'install', JSON.stringify(config)
	if config?
		onConfig config, true # new

exports.onConfig = onConfig = (config, isNew) !->
	log 'config', JSON.stringify(config)

	event = details: config.details
	if isNew
		event.created = 0|(new Date()/1000)
		event.by = App.userId()

	planner = !Db.shared.get('date') and config.type isnt 'announce'
	if planner # create plan
		if isNew
			event.options = {}
			event.answers = {}
			event.notes = {}
		config.options ||= {}
		Db.shared.set 'options', config.options

		# see if we need to save or remove the duration
		saveDuration = false
		for date, entry of config.options
			for k, v of entry
				saveDuration = true # at leat one time option defined
				break
		Db.shared.set 'duration', (if saveDuration then +event.duration else null)
	else
		event.date = +config.date
		event.time = +config.time
		event.duration = (if config.time is -1 then null else +config.duration)
		event.remind = +config.remind
		event.rsvp = config.rsvp
		if isNew
			event.attendance = {}

	Db.shared.merge event

	if !planner
		setRemindTimer()

exports.client_attendance = (value) !->
	if value is 0
		Db.shared.remove 'attendance', App.userId()
	else if value in [1, 2, 3] # going, maybe, notgoing
		Db.shared.set 'attendance', App.userId(), value

exports.client_setState = (optionId, state) !->
	Db.shared.set 'answers', optionId, App.userId(), 0|state

exports.client_pickDate = (optionId) !->
	[date, time] = optionId.split('-')
	answers = Db.shared.get 'answers'
	mapping =
		1: 1 # yes is going
		2: 3 # no is notgoing
		3: 2 # maybe is maybe
	if date
		# convert to an event
		Db.shared.set 'plannerCreated', (Db.shared.get 'created')
		Db.shared.set 'created', 0|(new Date()/1000) # update
		Db.shared.set 'date', +date
		Db.shared.set 'time', +(time||-1)
		Db.shared.set 'remind', 86400
		Db.shared.set 'rsvp', true
		if answers
			for oId, usersChosen of answers
				for userId, state of usersChosen when +state > 0
					Db.shared.set 'attendance', +userId, mapping[state]
		setRemindTimer()
		whenText = (if time? then timeToString(time)+' ' else '')
		whenText += dayToString(date)
		Event.create
			text: "Event date picked: #{whenText} (#{App.title()})"
			sender: App.userId()


exports.client_setNote = (optionId, note) !->
	Db.shared.set 'notes', optionId, App.userId(), note||null


exports.reminder = !->
	whenText = ''
	date = Db.shared.get('date')
	time = Db.shared.get('time')
	if time>=0
		append = ''
		if duration = Db.shared.get('duration')
			append = '-' + timeToString(time+duration)
		whenText = timeToString(time) + append + ' '

	whenText += dayToString(date)

	log "event reminder (#{whenText})"
	eventObj =
		text: "Event reminder: #{App.title()} (#{whenText})"
	include = []
	if rsvp = Db.shared.get('rsvp')
		for userId in App.userIds()
			include.push userId unless Db.shared.get('attendance', userId) is 2
		eventObj.for = include
	unless rsvp and include.length is 0
		Comments.post
			s: "remind"
		Event.create eventObj
	Db.shared.set 'reminded', Math.round(App.time())

setRemindTimer = !->
	remind = Db.shared.get('remind') ? 86400
	Timer.cancel 'reminder'

	log 'event, remind, App.time()', remind, App.time()
	return if remind<0 # -1 means no reminder

	date = Db.shared.get('date')
	time = Db.shared.get('time')
	startTime = dayToUnix(date)*1000 - remind*1000
	if remind >= 86400 # a day (or more) in advance
		startTime += (12*3600*1000)
	else if time>0
		startTime += time*1000

	remindTimeout = startTime - App.time()*1000
	if remindTimeout>0
		log 'setting remindTimeout', remindTimeout
		Timer.set remindTimeout, 'reminder'

exports.onHttp = (request) !->
	log 'request', JSON.stringify(request)

	request.setHeader 'Content-Type', 'text/calendar; charset=utf-8'
	request.setHeader 'Content-Disposition', 'attachment; filename=event.ics'

	title = App.title()
	details = Db.shared.get('details')
	uid = App.appId()+'-'+title

	date = new Date(Db.shared.get('date')*864e5)
	year = date.getUTCFullYear()
	month = date.getUTCMonth()+1
	month = (if month<10 then '0' else '')+month
	day = date.getUTCDate()
	day = (if day<10 then '0' else '')+day

	time = Db.shared.get('time')
	duration = Db.shared.get('duration')||0

	dateStringStart = year+''+month+''+day
	dateStringEnd = year+''+month+''+day
	if time>=0
		for tm, idx in [time, time+duration]
			hour = Math.floor((tm||0)/3600)
			hour = (if hour<10 then '0' else '')+hour
			minute = Math.floor((tm||0)%3600/60)
			minute = (if minute<10 then '0' else '')+minute
			seconds = Math.floor(tm%60)
			seconds = (if seconds<10 then '0' else '')+seconds
			if idx
				dateStringEnd += 'T'+hour+''+minute+''+seconds
			else
				dateStringStart += 'T'+hour+''+minute+''+seconds

	request.respond 200, "BEGIN:VCALENDAR\nVERSION:2.0\nPRODID:Happening Event\nBEGIN:VEVENT\nUID:#{uid}\nDTSTAMP;VALUE=DATE:#{dateStringStart}\nDTSTART;VALUE=DATE:#{dateStringStart}\nDTEND;VALUE=DATE:#{dateStringEnd}\nSUMMARY:#{title}\n"+(if details? then "DESCRIPTION:#{details}\n" else "")+"END:VEVENT\nEND:VCALENDAR"

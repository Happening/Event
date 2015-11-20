App = require 'app'
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

exports.getTitle = ->
	Db.shared.get('title')

exports.onInstall = (config) !->
	log 'install', JSON.stringify(config)
	if config?
		onConfig config, true # new

exports.onConfig = onConfig = (config, isNew) !->
	log 'config', JSON.stringify(config)
	if config.type is 'planner' # create plan
		writePlanner(config, isNew)
	else
		writeEvent(config, isNew)
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
		Db.shared.set 'date', date
		Db.shared.set 'time', time||-1
		Db.shared.set 'remind', 86400
		Db.shared.set 'rsvp', true
		if answers
			for oId, usersChosen of answers
				for userId, state of usersChosen when +state > 0
					Db.shared.set 'attendance', +userId, mapping[state]
		setRemindTimer()


exports.client_setNote = (optionId, note) !->
	Db.shared.set 'notes', optionId, App.userId(), note||null


exports.reminder = !->
	date = Db.shared.get('date')
	time = Db.shared.get('time')
	title = Db.shared.get('title')
	whenText = (if time>=0 then timeToString(time)+' ' else '')
	whenText += dayToString(date)

	log "event reminder (#{whenText})"
	eventObj =
		text: "Event reminder: #{title} (#{whenText})"
	include = []
	if rsvp = Db.shared.get('rsvp')
		for userId in App.userIds()
			include.push userId unless Db.shared.get('attendance', userId) is 2
		eventObj.for = include
	Event.create eventObj unless rsvp and include.length is 0
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

writeEvent = (values, isNew = false) ->
	event =
		title: values.title||"(No title)"
		details: values.details
		date: values.date
		time: values.time
		remind: values.remind
		rsvp: values.rsvp
	if isNew
		event.created = 0|(new Date()/1000)
		event.by = App.userId()
		event.attendance = {}
	Db.shared.merge event

writePlanner = (values, isNew = false) ->
	planner =
		title: values.title||"(No title)"
		details: values.details
	if isNew
		planner.created = 0|(new Date()/1000)
		planner.by = App.userId()
		planner.options = {}
		planner.answers = {}
		planner.notes = {}
	Db.shared.merge planner
	Db.shared.set 'options', (JSON.parse(values.options)||{})

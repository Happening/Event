Db = require 'db'
Plugin = require 'plugin'

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
		# TODO: set/update reminder

exports.client_attendance = (value) !->
	if value is 0
		Db.shared.remove 'attendance', Plugin.userId()
	else if value in [1, 2, 3] # going, maybe, notgoing
		Db.shared.set 'attendance', Plugin.userId(), value

exports.client_setState = (optionId, state) !->
	Db.shared.set 'answers', optionId, Plugin.userId(), 0|state

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
		Db.shared.set 'time', time||0
		Db.shared.set 'remind', 86400 # TODO: actually set reminder
		Db.shared.set 'rsvp', true
		if answers
			for oId, usersChosen of answers
				for userId, state of usersChosen when +state > 0
					Db.shared.set 'attendance', +userId, mapping[state]
		# TODO: notify about this new event?


exports.client_setNote = (optionId, note) !->
	Db.shared.set 'notes', optionId, Plugin.userId(), note||null

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
		event.by = Plugin.userId()
		event.attendance = {}
	Db.shared.merge event

writePlanner = (values, isNew = false) ->
	planner =
		title: values.title||"(No title)"
		details: values.details
	if isNew
		planner.created = 0|(new Date()/1000)
		planner.by = Plugin.userId()
		planner.options = {}
		planner.answers = {}
		planner.notes = {}
	Db.shared.merge planner
	log 'writing options', values.options
	Db.shared.set 'options', (JSON.parse(values.options)||{})

App = require 'app'
Comments = require 'comments'
Datepicker = require 'datepicker'
Db = require 'db'
Dom = require 'dom'
Event = require 'event'
Form = require 'form'
Icon = require 'icon'
Modal = require 'modal'
Obs = require 'obs'
Page = require 'page'
Server = require 'server'
Time = require 'time'
Ui = require 'ui'
{tr} = require 'i18n'

today = 0|(((new Date()).getTime() - (new Date()).getTimezoneOffset()*6e4) / 864e5)
attendanceTypes =
	1: tr "Going"
	2: tr "Maybe"
	3: tr "Not going"

if Db.shared
	shared = Db.shared.ref()
else
	shared = Obs.create()

exports.render = !->
	if shared.get('date')
		renderEvent()
	else
		renderPlanner()

	Comments.enable
		messages:
			remind: (c) ->
				remind = shared.get('remind') || 0
				if remind <= 0
					tr("This event is happening right now!")
				else if remind is 600
					tr("This event is happening in 10 minutes")
				else if remind is 3600
					tr("This event is happening in 1 hour")
				else if remind is 86400
					tr("This event is happening in 1 day")
				else if remind is 604800
					tr("This event is happening in 1 week")

renderEvent = !->
	Ui.top !->
		Dom.cls 'top1'
		Dom.style margin: 0

		Dom.div !->
			Dom.span !->
				Dom.style fontSize: '160%', fontWeight: 'bold'
				Dom.userText App.title()

		Dom.div !->
			append = ''
			if duration = shared.get('duration')
				append = ' - ' + Datepicker.timeToString(+shared.get('time')+duration)
			Dom.text Datepicker.timeToString(shared.get('time'))+append
			Dom.span !->
				Dom.style padding: '0 4px'
				Dom.text ' • '
			Dom.text Datepicker.dayToString(shared.get('date'))

		Dom.div !->
			Dom.style
				display: 'inline-block'
				padding: '6px 8px'
				fontSize: '75%'
				color: '#fff'
				marginTop: '8px'
				textTransform: 'uppercase'
				border: '1px solid #fff'
				borderRadius: '2px'
			Dom.text tr "Add to calendar"
			Dom.onTap !->
				if App.agent().android
					beginTime = Datepicker.dayToDate(shared.get('date'))
					time = Db.shared.get('time')
					if time>=0
						beginTime.setHours(Math.floor(time/3600))
						beginTime.setMinutes(Math.floor((time%3600)/60))
						beginTime.setSeconds(Math.floor(time%60))
					description = Db.shared.get('details') || ''
					intentOpts =
						_action: "android.intent.action.INSERT"
						_data: "content://com.android.calendar/events"
						_activity: 0
						allDay: time<0
						beginTime: beginTime.getTime()
						title: App.title()
						description: description
						availability: 0 # busy
					if duration = Db.shared.get('duration')
						intentOpts.endTime = beginTime.getTime() + duration * 1000
					ok = App.intent intentOpts
				else
					App.openUrl App.inboundUrl()

		Dom.div !->
			Dom.style
				fontSize: '75%'
				color: '#ddd'
				marginTop: '16px'
			Dom.text tr("Added by %1", App.userName(shared.get('by')))
			Dom.text " • "
			Time.deltaText shared.get('created')

	# details
	if details = shared.get('details')
		Form.label !->
			Dom.text tr("Details")
		Dom.div !->
			Dom.userText details

	# attendance info..
	if shared.get('rsvp')
		Form.label tr("Attendance")
		Dom.div !->
			attendance =
				1: []
				2: []
				3: []
			shared.forEach 'attendance', (user) !->
				attendance[user.get()].push user.key()

			userAtt = shared.get('attendance', App.userId())
			for type in [1, 2, 3] then do (type) !->
				chosen = userAtt is type
				Dom.div !->
					Dom.style Box: 'top', margin: '12px 0', fontSize: '85%'

					Ui.button !->
						Dom.style margin: 0, width: '70px', textAlign: 'center', border: '1px solid '+App.colors().highlight
						if chosen
							Dom.style backgroundColor: App.colors().highlight, color: '#fff'
						else
							Dom.style backgroundColor: 'transparent', color: App.colors().highlight
						Dom.text attendanceTypes[type]
					, !->
						Server.sync 'attendance', (if chosen then 0 else type), !->
							shared.set 'attendance', App.userId(), (if chosen then null else type)

					Dom.div !->
						Dom.style fontWeight: 'bold', padding: '6px 8px'
						Dom.text ' (' + attendance[type].length + ')'

					Dom.div !->
						Dom.style Flex: 1, fontWeight: 'bold', padding: '6px 0'

						for uid, k in attendance[type] then do (uid) !->
							if k
								Dom.span !->
									Dom.style color: '#999'
									Dom.text ', '
							Dom.span !->
								Dom.style
									whiteSpace: 'nowrap'
									color: (if App.userId() is +uid then 'inherit' else '#999')
									padding: '2px 4px'
									margin: '-2px -4px'
								Dom.text App.userName(uid)
								Dom.onTap (!-> App.showMemberInfo(uid))



renderPlanner = !->
	getState = (optionId, userId) -> shared.get('answers', optionId, userId||App.userId()) || 0

	renderIcon = (optionId, userId, edit, content) !->
		Dom.div !->
			Dom.style
				Box: 'middle center'
				padding: '10px'
				minWidth: '29px'
				minHeight: '29px'
				margin: if edit then 0 else '-9px 0'
				opacity: if edit then 1 else 0.3
			Dom.img !->
				icon = ['unknown', 'yes', 'no', 'maybe'][getState(optionId, userId)]
				Dom.prop src: App.resourceUri("#{icon}.png")
				Dom.style
					maxWidth: '24px'
					maxHeight: '24px'
					width: 'auto'
					verticalAlign: 'middle'
			content?()

	userId = App.userId()

	Page.setCardBackground()
	Ui.top !->
		Dom.style backgroundColor: '#fff'
		ownerId = App.ownerId()

		Dom.div !->
			Dom.style Box: true
			Ui.avatar App.userAvatar(ownerId), onTap: !-> App.showMemberInfo(ownerId)

			
			Dom.h1 !->
				Dom.style Flex: 2, display: 'block', marginLeft: '10px'
				Dom.text App.title()

		Dom.div !->
			Dom.style margin: '0 0 0 50px'
			Dom.richText shared.get('details') || ''

			Dom.div !->
				Dom.style
					fontSize: '70%'
					color: '#aaa'
					padding: '6px 0 0'
				if ownerId
					Dom.text App.userName(ownerId)
					Dom.text " • "
				Time.deltaText App.created()


	# create a mapping from db to optionsO that uses 'day-time' keys
	optionsO = Obs.create {}
	shared.observeEach 'options', (opt) !->
		oDay = 0|opt.key()
		if !opt.ref().count().get()
			optionsO.set oDay+'', {}
		else
			opt.observeEach (time) !->
				optKey = oDay+'-'+time.key()
				optionsO.set optKey, true
				Obs.onClean !->
					optionsO.remove optKey
		Obs.onClean !->
			optionsO.remove oDay

	users = App.users.get()
	expanded = Obs.create(Page.state.peek('exp'))
	Ui.list !->
		if !optionsO.count().get()
			Ui.emptyText tr("No date options configured yet")
		else
			optionsO.observeEach (option) !->
				optionId = option.key()
				[day, time] = optionId.split('-')
				dayName = Datepicker.dayToString(day, true)
				if time
					append = ''
					if duration = shared.get('duration')
						append = '-' + Datepicker.timeToString(+time+duration)
					optionName = dayName + ' (' + Datepicker.timeToString(time) + append + ')'
				else
					optionName = dayName
				Ui.item !->
					Dom.style Box: 'middle', padding: 0
					Dom.style borderBottom: 'none' if expanded.get(optionId)

					Dom.div !->
						Dom.style Box: 'middle', Flex: 1, padding: '8px'

						Dom.div !->
							cnt = 0
							if answers = shared.get('answers', optionId)
								for uid, answer of answers
									if users[uid] and answer is 1
										cnt++
							Dom.style
								Box: "middle center"
								padding: '5px'
								fontSize: '120%'
								marginRight: '10px'
								backgroundColor: '#ddd'
								color: if cnt then 'black' else '#aaa'
								borderRadius: '4px'
								minWidth: '25px'
							Dom.text cnt
						Dom.div !->
							Dom.style Flex: 1
							Dom.div !->
								Dom.style fontWeight: 'bold'
								Dom.text optionName
								Dom.br()
								Dom.span !->
									notesCnt = shared.ref('notes').count(optionId).get()
									Dom.text if notesCnt then tr("%1 note|s", notesCnt) else tr("No notes")
									Dom.style fontWeight: 'normal', fontSize: '80%', color: (if notesCnt then 'inherit' else '#aaa')

						Dom.div !->
							Dom.style color: '#aaa', margin: '0 5px', border: '8px solid transparent'
							if expanded.get(optionId)
								Dom.style borderBottom: '8px solid #ccc', marginTop: '-8px'
							else
								Dom.style borderTop: '8px solid #ccc', marginBottom: '-8px'

						Dom.onTap !->
							expanded.modify optionId, (v) -> if v then null else true
							Page.state.set('exp', expanded.get())

					if !expanded.get(optionId)
						Form.vSep()
						renderIcon optionId, userId, true, !->
							Dom.onTap !->
								state = (getState(optionId)+1)%4
								Server.sync 'setState', optionId, state, !->
									shared.set 'answers', optionId, userId, state
					else
						# to prevent a tap-highlight in this area
						Dom.div !->
							Dom.style width: '50px'

				if expanded.get(optionId)
					Ui.item !->
						Dom.style Box: "right", padding: '0 0 8px 0'
						Dom.span !->
							Dom.style display: 'block', maxWidth: '20em'
							App.users.observeEach (user) !->
								isMine = +user.key() is +userId
								Dom.span !->
									Dom.style Box: "middle", margin: (if isMine then 0 else '4px 0'), textAlign: 'right'
									Dom.div !->
										Dom.style Flex: 1
										if isMine
											Dom.style padding: '5px'
										else
											Dom.style margin: '0 5px'

										Dom.span !->
											Dom.style fontWeight: 'bold'
											Dom.text user.get('name')

										note = shared.get('notes', optionId, user.key())
										if isMine
											Dom.text ': '
											Dom.text note if note
											Dom.span !->
												Dom.style color: App.colors().highlight
												Dom.text (if note then ' ' + tr "Edit" else tr "Add a note")
											Dom.onTap !->
												Form.prompt
													title: tr('Note for %1', optionName)
													value: note
													cb: (note) !->
														Server.sync 'setNote', optionId, note||null, !->
															shared.set 'notes', optionId, userId, note||null
										else if note
											Dom.text ': '+note

									Ui.avatar App.userAvatar(user.key()),
										style: margin: '0 8px'
										size: 24
										onTap: !-> App.showMemberInfo(user.key())

									renderIcon optionId, user.key(), isMine, if isMine then !->
										Dom.onTap !->
											state = (getState(optionId)+1)%4
											Server.sync 'setState', optionId, state, !->
												shared.set 'answers', optionId, userId, state


							, (user) ->
								if +user.key() is +userId
									-1000
								else
									user.get('name')

							if App.userIsAdmin() or App.ownerId() is App.userId()
								Dom.div !->
									Dom.style textAlign: 'right', paddingRight: '8px'
									Ui.button tr("Pick date"), !->
										Modal.confirm tr("Pick %1?", optionName), tr("Members will no longer be able to change their availability"), !->
											Server.sync 'pickDate', optionId

			, (option) -> # sort order
				option.key()


renderEventSettings = !->
	curDate = shared.get('date')||today

	curTime = Obs.create(shared.get('time') || -1)
	Dom.div !->
		Dom.style Box: 'horizontal'

		Form.box !->
			Dom.style Flex: 1, paddingRight: '12px'
			Dom.text tr("Event date")
			[handleChange] = Form.makeInput
				name: 'date'
				value: curDate
				content: (value) !->
					Dom.div Datepicker.dayToString(value)

			Dom.onTap !->
				cur = null
				Modal.confirm tr("Select date"), !->
					cur = Datepicker.date
						value: curDate
				, !->
					handleChange cur.get()
					curDate = cur.get()

		Form.vSep()

		Form.box !->
			Dom.style Flex: 1, paddingLeft: '12px'
			Dom.text tr("Event time")
			[handleChange] = Form.makeInput
				name: 'time'
				value: curTime.peek()
				content: (value) !->
					Dom.div Datepicker.timeToString(value)

			Dom.onTap !->
				val = (if curTime.peek()<0 then null else curTime.peek())
				Modal.show tr("Enter time"), !->
					Datepicker.time
						value: val
						onChange: (v) !->
							val = v
				, (choice) !->
					return if choice is 'cancel'
					newVal = (if choice is 'clear' then -1 else val)
					handleChange newVal
					curTime.set newVal
				, ['cancel', tr("Cancel"), 'clear', tr("All day"), 'ok', tr("Set")]


	renderDurationInput shared.get('duration')||0, curTime

	Form.box !->
		remind = shared.get('remind')
		if !remind? then remind = 86400 # if 0 then it should remain 0

		getRemindText = (r) ->
			if r is -1
				tr("No reminder")
			else if r is 0
				tr("At time of event")
			else if r is 600
				tr("10 minutes before")
			else if r is 3600
				tr("1 hour before")
			else if r is 86400
				tr("1 day before", r)
			else if r is 604800
				tr("1 week before", r)

		Dom.text tr("Reminder")
		[handleChange] = Form.makeInput
			name: 'remind'
			value: remind
			content: (value) !->
				Dom.div !->
					Dom.text getRemindText(value)

		Dom.onTap !->
			Modal.show tr("Remind members"), !->
				opts = [0, 600, 3600, 86400, 604800, -1]
				for rem in opts then do (rem) !->
					Ui.item !->
						Dom.text getRemindText(rem)
						if remind is rem
							Dom.style fontWeight: 'bold'

							Dom.div !->
								Dom.style
									Flex: 1
									padding: '0 10px'
									textAlign: 'right'
									fontSize: '150%'
									color: App.colors().highlight
								Dom.text "✓"
						Dom.onTap !->
							handleChange rem
							remind = rem
							Modal.remove()

	Obs.observe !->
		ask = Obs.create(shared.get('rsvp') || true)
		Form.check
			name: 'rsvp'
			value: shared.func('rsvp') || true
			text: tr("Ask people if they're going")
			onChange: (v) !->
				ask.set(v)


renderPlannerSettings = !->
	datesO = null # consists of { dayNr: true } entries, used by Datepicker.date
	optionsO = Obs.create {} # consists of { dayNr: time: true } (or dayNr: {}) entries

	# construct initial optionsO from db values
	curDates = {}
	for day, times of shared.get('options')
		curDates[day] = true
		optionsO.set day, {}
		for t, v of times
			(o = {})[t] = true
			optionsO.merge day, o

	Form.addObs 'options', optionsO

	Dom.div !->
		Dom.style Box: "center", marginTop: '12px', borderBottom: '1px solid #ddd'
		datesO = Datepicker.date
			mode: 'multi'
			value: curDates

		# map selected days to optionsO
		Obs.observe !->
			datesO.observeEach (entry) !->
				eDay = entry.key()
				optionsO.merge eDay, {}
				Obs.onClean !->
					optionsO.remove eDay

	optionsCnt = Obs.create 0
	Obs.observe !->
		cnt = 0
		for k, times of optionsO.get()
			tCnt = 0
			for x, y of times
				tCnt++
			tCnt = Math.max(tCnt, 1)
			cnt += tCnt
		optionsCnt.set cnt

	lastTime = null
	dayTimeOptions = (day) !->
		addTimeOption = !->
			Modal.show tr("Add time option"), !->
				Datepicker.time
					value: lastTime
					onChange: (v) !->
						lastTime = v
			, (choice) !->
				if choice is 'add' and lastTime
					optionsO.set day, lastTime, true
					showTimeOptions()
			, ['cancel', tr("Cancel"), 'add', tr("Add")]

		showTimeOptions = !->
			Modal.show tr("Time options"), !->
				optionsO.observeEach day, (timeOption) !->
					Ui.item !->
						Dom.div !->
							Dom.style Flex: 1, fontSize: '125%', fontWeight: 'bold', paddingLeft: '4px'
							Dom.text Datepicker.timeToString(timeOption.key())
						Icon.render
							data: 'cancelround'
							size: 32
							onTap: !->
								optionsO.remove day, timeOption.key()
				Ui.item !->
					Dom.style color: App.colors().highlight, paddingLeft: '12px'
					Dom.text tr('+ Add option')
					Dom.onTap !->
						Modal.remove()
						addTimeOption()


		if optionsO.ref(day).count().get()
			# multiple time options
			showTimeOptions()
		else
			# first time option
			addTimeOption()

	Obs.observe !->
		optionsO.observeEach (entry) !->
			oDay = entry.key()
			Ui.item !->
				Dom.style padding: 0
				Dom.div !->
					Dom.style Flex: 1, padding: '12px'
					Dom.text Datepicker.dayToString(oDay)
					Dom.div !->
						Dom.style fontSize: '75%', color: '#aaa', marginTop: '3px'
						ts = (Datepicker.timeToString(t) for t, v of entry.get())
						if ts.length
							Dom.text ts.join(' / ')
						else
							Dom.text tr("No time(s) specified")
					Dom.onTap !->
						dayTimeOptions oDay
				Form.vSep()

				Icon.render
					data: 'cancel'
					size: 24
					style: padding: '18px'
					onTap: !->
						datesO.remove oDay # syncs to optionsO

		, (entry) -> entry.key()

	Form.condition ->
		tr("A minimum of two options is required") if optionsCnt.peek()<2

	Obs.observe !->
		showDuration = false
		for date, entry of optionsO.get() when !showDuration
			for k, v of entry
				showDuration = true # at least one time option defined
				break
		if !showDuration
			return

		renderDurationInput shared.get('duration')||0

	Dom.div !->
		Dom.style Box: 'center middle', textAlign: 'center', color: '#aaa', padding: '8px', fontSize: '85%'
		oc = optionsCnt.get()
		Dom.text (if !oc then tr("No dates selected yet") else tr("Poll will have %1 option|s", oc))




exports.renderSettings = !->
	Form.input
		name: '_title'
		text: tr("Event name")
		value: App.title()

	Form.condition (val) ->
		tr("An event name is required") if !val._title

	Form.text
		name: 'details'
		text: tr "Details about the event"
		autogrow: true
		value: shared.func('details')

	showPlanner = Obs.create (if shared.get('date') then false else true)
	Obs.observe !->
		if !Db.shared # only offer choice on install
			Form.segmented
				name: 'type'
				value: 'announce'
				segments: ['announce', tr("Fixed date"), 'plan', tr("Date poll")]
				onChange: (v) !-> showPlanner.set(v is 'plan')
				description: !->
					Dom.text (if showPlanner.get() then tr("Asks people to vote for the best date") else tr("Enter date and time below"))

		if !showPlanner.get()
			# select date
			renderEventSettings()
		else
			renderPlannerSettings()


renderDurationInput = (duration, timeO) !->
	Form.box !->
		allDay = if timeO? then timeO.get() is -1 else false
		Dom.style color: if allDay then '#aaa' else ''
		Dom.text tr("Duration")
		if allDay
			Dom.div tr("No event time specified")
		else
			[handleChange] = Form.makeInput
				name: 'duration'
				value: duration
				onChange: (v) !->
					duration = v
				content: (value) !->
					Dom.div !->
						hours = Math.floor(value/3600)
						mins = (value - hours*3600)/60
						Dom.text if hours and mins
							tr("%1 hour|s and %2 min|s", hours, mins)
						else if hours
							tr("%1 hour|s", hours)
						else if mins
							tr("%1 min|s", mins)
						else
							tr("Not specified")

			Dom.onTap !->
				Modal.show tr("Duration"), !->
					Datepicker.time
						value: duration
						onChange: (v) !->
							handleChange v
							duration = v


#!/usr/bin/env coffee

fs = require "fs"
path = require "path"
async = require "async"
gm = require "gm"
randomstring = require "randomstring"

splitOnNewLine = (str) -> str.trim().split /\r\n|\n/

chunkArray = (array, chunkSize) ->
	[].concat.apply [],
		array.map (elem,i) ->
			if i % chunkSize
				[]
			else
				[array.slice i, i + chunkSize]

convertImage = (src, dest, _cb) ->
	gm(src).write(dest, _cb)

findQuizzesFromQaFolder = (src) ->
	iniFiles = []
	i = 1

	while fs.existsSync path.join src, "qa#{i}.ini"
		iniFiles.push fs.readFileSync path.join(src, "qa#{i}.ini"), "utf8"
		i++

	return iniFiles

parseStrangeIni = (str, dir) ->
	lines = splitOnNewLine str.trim()
	obj = {}

	for line in lines

		# Ignore comments
		continue if line.match /^--/
		
		# Keys/props
		try
			[full, key, prop] = line.match /^(.+):=(.+)/
		catch err
			console.log "Invalid line '#{line}' in #{dir}"
			continue
		
		# Replace FileLocation^ thing...
		# I assume that ^ is a concat operator
		# Can't figure out subtleties, so just replace the
		# 2 occurences I've found: FileLocation & FileLocation^"str"
		if prop.trim() is "FileLocation"
			prop = dir
		else
			prop = prop.replace "FileLocation^", "\"#{dir}/\" +"
			# eval() is a security issue, but will do for now
			prop = eval prop
		
		# Replace windows dir separator with unix
		if typeof prop is "string"
			prop = prop.replace `/\\/g`, "/"

		obj[key] = prop
		
	return obj

fixQuizTexts = (questions) ->
	questions.map (q) ->
		q.question.text = q.question.text.replace(/\|/g, "\n").trim()
		q.answer.text = q.answer.text.replace(/\|/g, "\n").trim()

		return q

parseQuizTxt = (str, picPath) ->
	# Structure: qText, qImage, aText, aImage
	# Question/answer text needn't exist
	# Image is recognised as a line containing .bmp, .jpg or .avi
	# Image can have added functions with semicolons
	# eg: neck1.bmp;arrow(30,30);label(30,30,text)
	# Functions fail silently if don't have all params
	# Image path and functions are case insensitive
	# The char "|" is converted into a new line

	lines = splitOnNewLine str.trim()
	quiz = []

	i = 0
	currPart = "question"
	toggleCurrPart = ->
		if currPart is "question"
			currPart = "answer"
		else
			currPart = "question"

	for line in lines
		quiz[i] ?= {}
		quiz[i].question ?= text: "", media: null
		quiz[i].answer ?= text: "", media: null
		nextPart = true

		# Check whether line is blank image
		if line.match /^\s*none\s*$/i
			quiz[i][currPart].media = null

		# Check whether line is image/video
		else if line.match /\S*\.(bmp|jpg|avi)/i
			[match] = line.match /\S*\.(bmp|jpg|avi)/i
			quiz[i][currPart].media = path.join picPath, match

			# Check for label/arrow functions
			chunks = line.split ";"

			if chunks.length > 1
				for chunk in chunks
					if chunk.match /arrow\((.*)\)/
						[full, paramStr] = chunk.match /arrow\((.*)\)/

						params = paramStr.split ","

						quiz[i][currPart].arrows ?= []
						quiz[i][currPart].arrows.push params
					if chunk.match /label\((.*)\)/
						[full, paramStr] = chunk.match /label\((.*)\)/

						params = paramStr.split ","

						quiz[i][currPart].labels ?= []
						quiz[i][currPart].labels.push params

		# If not an image, then append line to question/answer
		else
			quiz[i][currPart].text += line + "\n"

			# Don't move onto next part
			nextPart = false

		if nextPart
			# Answer means end of card
			if currPart is "answer" then i++

			# Toggle b/w building Q or A
			toggleCurrPart()

	return fixQuizTexts quiz

bundleQuizMedia = (quiz, dest, _cb) ->
	newQuiz = JSON.parse JSON.stringify quiz
	mediaDir = "media"
	media = {}

	# Use a queue to avoid file access limits
	queue = async.queue ((task, _cb) ->
		convertImage task.src, task.dest, _cb
	), 2

	unless fs.existsSync path.join dest, mediaDir
		fs.mkdirSync path.join dest, mediaDir

	for q in newQuiz
		for part in ["question", "answer"]
			mediaSrc = q[part].media

			continue unless mediaSrc

			if media[mediaSrc]
				mediaDest = media[mediaSrc]
			else
				ext = path.extname mediaSrc
				newExt = (if ext.match /\.(bmp|jpg)/i then ".png" else ext)

				mediaDest = path.join dest, mediaDir, path.basename(mediaSrc, ext) +
					randomstring.generate(7) + newExt

				media[mediaSrc] = mediaDest

				if ext.match /\.(bmp|jpg)/i
					task = src: mediaSrc, dest: mediaDest
					queue.push task, (err) ->
						console.error err if err
				else
					fs.createReadStream(mediaSrc)
						.pipe(fs.createWriteStream(mediaDest))

			q[part].media = mediaDest

	queue.drain = (err) -> console.error err if err

	return newQuiz

saveQuizzesFromIni = (iniFile, src, dest) ->
	parsedIni = parseStrangeIni iniFile, src
	i = 1

	while parsedIni["topic" + i]
		quizPath = path.join parsedIni.filePath, parsedIni["file" + i]
		quizDest = path.join dest, parsedIni["topic" + i].replace(/(\s+)|\//g, "_") + ".json"
		quizTxt = fs.readFileSync quizPath, "utf8"

		parsedQuiz = parseQuizTxt quizTxt, parsedIni["picPath" + i]

		parsedQuiz2 = bundleQuizMedia parsedQuiz, dest, (->)

		quiz =
			title: parsedIni["topic" + i]
			questions: parsedQuiz2
			author: parsedIni["author" + i]

		fs.writeFileSync quizDest, JSON.stringify quiz, null, "\t"

		i++


do start = ->
	throw new Error "Need src and dest paths" unless process.argv.length >= 4

	src = path.resolve process.argv[2]
	dest = path.resolve process.argv[3]

	iniFiles = findQuizzesFromQaFolder src

	for iniFile in iniFiles
		saveQuizzesFromIni iniFile, src, dest



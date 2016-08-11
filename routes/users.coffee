request = require 'request'
Feed = require 'feed'

module.exports = (req, res, next) ->
	user = req.params[0]
	format = req.params[1]

	request "https://vine.co/api/users/profiles/#{user}", (error, response, body) ->
		return next error if error?
		unless response.statusCode is 200
			error = new Error "Unexpected response code #{response.statusCode} while querying profile"
			error.status = 500
			return next error
		body = JSON.parse body
		if not body.success or body.error
			error = new Error "Error retrieving profile. Code: '#{body.code}', message '#{body.error}'"
			error.status = 500
			return next error

		profile = body.data
		feed = new Feed
			title: "Vines by #{profile.username}"
			description: "" # Required in RSS
			link: "https://vine.co/u/#{profile.userId}"
			image: profile.avatarUrl

		request "https://vine.co/api/timelines/users/#{user}", (error, response, body) ->
			return next error if error?
			unless response.statusCode is 200
				error = new Error "Unexpected response code #{response.statusCode} from vine.co"
				error.status = 500
				return next error
			body = JSON.parse body
			if not body.success or body.error
				error = new Error "Error from vine.co. Code: '#{body.code}', message '#{body.error}'"
				error.status = 500
				return next error

			for record in body.data.records
				id = record.permalinkUrl.replace /.*\//, ''
				feed.addItem
					title: record.description
					link: record.permalinkUrl
					description: """
						<iframe
								class="vine-embed"
								src="https://vine.co/v/#{id}/embed/postcard?related=0"
								width="600"
								height="600"
								frameborder="0"></iframe>
						<div>
							<small>
								<a href="#{record.videoUrl}">Direct link to video</a>
							</small>
						</div>
					"""
					date: new Date record.created
					image: record.thumbnailUrl
					author: [
						name: record.username
						link: "https://vine.co/u/#{record.userId}"
					]

			payload = feed.render if format is 'atom' then 'atom-1.0' else 'rss-2.0'
			res.set 'Content-Type': if format is 'atom' then 'application/atom+xml' else 'application/rss+xml'
			res.send payload

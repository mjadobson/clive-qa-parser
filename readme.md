clive-qa-parser
===============

Parses CLIVE Q&A folder to easy JSON format.

Install:
--------

	npm install clive-qa-parser -g

You will also need graphicsmagick & coffee-script installed on your system.

Usage:
------

	clive-qa-parser [src] [dest]

Where `src` is the QA folder, and `dest` is where the *.json files will be written.

Output Data Format:
-------------------

```json
{
	"title": "Test Title",
	"questions": [
		{
			"question": {
				"text": ".. Question text ..",
				"media": "./media/kidg277L2Otrz.png",
			},
			"answer": {
				"text": ".. Answer text ..",
				"media": null
			}
		},
		{
			"question": {
				"text": ".. Question text 2 ..",
				"media": "./media/34ngcv7L2pxy5.png",
				"labels": [
					["99", "212", "g"]
				],
				"arrows": [
					["253", "143", "g"],
					["103", "72", "g"]
				]
			},
			"answer": {
				"text": ".. Answer text 2 ..",
				"media": "./media/9dgg4fhs8fhjc.png"
			}
		}
	]
}
```

Notes:
-----

* Only works in case-insensitive envs (ie: Mac, Windows)

License:
--------

BSD

Author:
-------

Matthew Dobson - mjadobson@gmail.com

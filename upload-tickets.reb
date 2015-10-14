REBOL [
    title: "CureCode Uploader"
    author: "John Kenyon"
    date: 21-08-2015
    needs: [
        http://reb4.me/r3/altjson
        http://reb4.me/r3/form-date
    ]
]

db-base: %tickets/

github-config: context [
https://github.com/rebolbot/rebol-issues
    issue-api-url: https://api.github.com/repos/rebolbot/rebol-issues/import/issues
    issue-url: https://github.com/rebolbot/rebol-issues/issues
    auth-token: "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX"
]

dummy-ticket: [
    summary: "Dummy"
    description: {Placeholder ticket to keep ticket numbering in line with curecode}
    code: #[none]
    version: ""
    severity: "trivial"
    status: "dismissed"
    resolution: "open"
    priority: "none"
    type: "Issue"
    platform: "All"
    created: 12-Dec-2012/12:12:12
    modified: 12-Dec-2012/12:12:12
    user: "Rebolbot"
    category: "n/a"
    reproduce: "Always"
    fixed-in: #[none]
    project: "REBOL 3.0"
    comments: [ ]
    history: [ ]
]

upload-ticket: func [config issue /local label-data] [
    if error? err: try [
        write config/issue-api-url compose/deep [
            POST [
                Accept: "application/vnd.github.golden-comet-preview"
                Authorization: (join "token " config/auth-token)
            ]
            (issue)
        ]
    ] [
        print mold err
        halt
    ]
]

; Helper function to insert either markdown or textile markup
md-tx: func [ date md tx ] [ either date > 2009/04/20/19:00:00+0:00 [ md ] [ tx ] ]

markup-code: func [ date text /local other-char code-rule mark ] [
    if not equal? last text newline [ append text newline ] ;simplifies parse rules
    other-char: complement charset [ #"A" - #"Z" "^/" " " "^M" ]
    code-rule: [ any space other-char thru newline ]
    parse/case text [
        some [
            mark: some code-rule
            (mark: insert mark (md-tx date "^/```rebol^/" "^/bc.. ")) :mark
            some code-rule
            mark: (mark: insert mark md-tx date "```^/" "^/p. ^/") :mark
            |
            thru newline
        ]
    ]
    text
]

print "Start uploading from?:"
start-ticket: to-integer input
print "How many to upload?:"
number-to-upload: to-integer input

for current-ticket start-ticket (start-ticket + number-to-upload - 1) 1 [
    print [ "Uploading CC ticket:" current-ticket ]
    ticket: attempt [ load read rejoin [ db-base current-ticket ".r" ] ] 
    either none? ticket [
        ticket: copy dummy-ticket
        print "Inserting dummy issue"
        description: ticket/description
    ] [
        markup-code ticket/created ticket/description
        description: rejoin [
            "_Submitted by:_ " md-tx ticket/created "**" "*" ticket/user
            md-tx ticket/created "**" "*" newline newline
            ticket/description newline
            either none? ticket/code [
                "" 
            ] [
                rejoin [
                    md-tx ticket/created "```rebol^/" "bc.. ^/" 
                    ticket/code
                    md-tx ticket/created "^/```^/" "^/^/p. ^/"
                ]
            ] newline
            "<sup>**CC - Data** [ Version: " ticket/version
            " Type: " ticket/type
            " Platform: " ticket/platform
            " Category: " ticket/category
            " Reproduce: " ticket/reproduce
            " Fixed-in:" ticket/fixed-in
            " ]</sup>"
        ]
    ]
    ; Are there any labels to add?
    labels: collect [
        switch ticket/type [
            "Bug" [ keep "Type.bug" ]
            "Wish" [ keep "Type.wish" ] 
            "Note" [ keep "Type.note" ]
            "Nuts" [ keep "Type.alien" ]
        ]
        switch ticket/severity [
            "major" [ keep "Status.important" ]
            "crash" [ keep "Status.important" ]
            "block" [ keep "Status.important" ]
            "not a bug" [ keep "Status.dismissed" ]
        ] 
        switch ticket/priority [
            "high" [ keep "Status.important" ]
            "urgent" [ keep "Status.important" ]
            "immediate" [ keep "Status.important" ]
        ]
    ]

    ;Capture ladislav's test written comments into a label
    foreach cmt ticket/comments [
        parse cmt/4 [
            thru ["added"|"in the"]
            thru "test"
            thru "suite"
            to end
            (append labels "Test.written") ]
    ]

    new-issue: copy []
    new-issue: compose/deep [
        <issue> [
            <title> (ticket/summary)
            <body> (description)
            <created_at> (form-date ticket/created "%c")
            <closed> (either any [ ticket/status = "dismissed" ticket/status = "complete" ] [ true ] [ false ])
            <labels> [ (labels) ]
        ]
        <comments> [
            (map-each [cmt] ticket/comments [
                compose/deep [
                    <created_at> (form-date cmt/3 "%c")
                    <body> (rejoin[
                        "_Submitted by:_ " md-tx cmt/3 "**" "*"  
                        cmt/2 md-tx cmt/3 "**" "*" newline newline
                        markup-code cmt/3 cmt/4 newline
                    ])
                ]
            ])
        ]
    ]
    print to-json new-issue

    ; Create the ticket - check the number allocated and abort if it is not expected
    upload-ticket github-config to-json new-issue
    wait 0:00:04 ; allow the ticket to be created

    if error? try [ to-string read rejoin [ github-config/issue-url "/" current-ticket ] ] [
        print "Ticket not created - emergency stop"
        probe mold err
        halt
    ]

    print [ "Done with ticket:" current-ticket ]
    ;input ; wait on each loop while debugging
]

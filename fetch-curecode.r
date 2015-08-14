REBOL [title: "CureCode Fetcher" author: "Andreas Bolka" date: 2013-03-03]

db-base: %tickets/

api-url: http://curecode.org/rebol3/api.rsp?

fail: func [msg] [
    print msg
    quit/return 1
]

latin1-to-utf8: func [
    "Transcodes a Latin-1 encoded string to UTF-8"
    bin [binary!] "Bytes of Latin-1 data"
] [
    to-binary collect [
        foreach b bin [
            keep to-char b
        ]
    ]
]

api-load: func [params] [
    first load/all latin1-to-utf8 read join api-url params
]

download-ticket: func [num /local ticket fname] [
    unless parse api-load join "type=ticket&show=all&id=" num [
        'ok set ticket block!
    ] [
        fail ["Could not load ticket data:" num]
    ]
    save/all rejoin [db-base num %.r] reduce [append compose [id: (num)] ticket]
    ticket
]

main: funct [/local ticket-num ticket-date] [
    make-dir db-base
    local-date: attempt [load db-base/state.r]
    remote-date: none

    either none? local-date [
        print "Fetching all tickets."
    ] [
        print ["Checking for changes since" local-date]
    ]

    ;; "Ping" first: obtain the most recent remote change.
    unless parse api-load "type=list&filter=6&mode=brief&range=1x1" [
        'ok into [into [5 skip set remote-date date! 5 skip]]
    ] [
        fail "Could not load most recent change."
    ]

    changes: either attempt [ local-date >= remote-date ] [
        ;; Local timestamp is equal/newer than most recent remote. No changes
        ;; to fetch.
        []
    ] [
        ;; Retrieve full list of changes. If performance (time/space) becomes
        ;; an issue, do that in batches (range=<start>x<end>) instead of
        ;; loading all changes at once.
        reverse collect [
            unless catch [
                parse api-load "type=list&filter=6&mode=brief" [
                    'ok into [
                        any [
                            into [
                                set ticket-num integer!
                                4 skip
                                set ticket-date date!
                                5 skip
                                (
                                    either any [
                                        none? local-date
                                        local-date < ticket-date
                                    ] [
                                        keep ticket-num
                                    ] [
                                        ;; We assume the list of changes
                                        ;; returned by filter=6 is sorted
                                        ;; reverse chronologically. So we abort
                                        ;; as soon as we see a change older
                                        ;; than what we already have.
                                        throw true
                                    ]
                                )
                            ]
                        ]
                    ]
                ]
            ] [
                fail "Could not load list of changes."
            ]
        ]
    ]

    print ["Most recent remote change:" remote-date]
    print [length? changes "changes to fetch."]

    foreach num changes [
        prin ajoin ["Fetching #" num]
        ticket: download-ticket num
        save db-base/state.r ticket/modified
        print ajoin [": " ticket/modified]
    ]

    print ["Up to date."]
]

main

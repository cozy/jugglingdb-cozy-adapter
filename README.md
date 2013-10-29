## About

*jugglindb-cozy-adapter* is an adapter for
[JugglingDB](https://github.com/1602/jugglingdb "JugglingDB") required by
cozy applications to use the Cozy Data System.


[![Build
Status](https://travis-ci.org/mycozycloud/jugglingdb-cozy-adapter.png?branch=master)](https://travis-ci.org/mycozycloud/jugglingdb-cozy-adapter)



## Setup for Compound

First add it to your project dependencies (package.json file), or install it
directly:

    npm install jugglingdb-cozy-adapter

Then in your *config/database.json* file, add this:

    {
        "driver":   "jugglingdb-cozy-adapter",
        "url": "http://localhost:9101/"
    }

Url parameter is optional. Don't forget the trailing slash at the end of the
url.  Of course to work correctly, the adapter required Cozy Data System and
CouchDB up and running.

## Usage

Check
[test file](https://github.com/mycozycloud/jugglingdb-cozy-adapter/blob/master/tests.coffee)
for documented usage of methods available in this adapter.


### Documents

```coffeescript
# Existence
Note.exists 123, (err, isExist) ->
    console.log isExist

# Find
Note.find 321, (err, note) ->
    console.log note

# Create
Note.create { id: "321", "content":"created value"}, (err, note) ->
    console.log note.id

# Update
note.save (err) ->
    console.log err

# Update attributes
note.updateAttributes title: "my new title", (err) ->
    console.log err

# Upsert
Note.createOrUpdate @data.id, (err, note) ->
    console.log err

# Delete
note.destroy (err) ->
    console.log err
```


### Indexation

```coffeescript
# Index document fields
note.index ["title", "content"], (err) ->
    console.log err

# Search through indexes
Note.search "dragons", (err, notes) ->
    console.log notes
```


### Files

```coffeescript
# Attach file
note.attachFile "./test.png", (err) ->
    console.log err

# Get file
stream = @note.getFile "test.png", (err) ->
     console.log err
stream.pipe fs.createWriteStream('./test-get.png')
```


### Requests

```coffeescript
# Define request
map = (doc) ->
    emit doc._id, doc
    return

Note.defineRequest "every_notes", map, (err) ->
    console.log err

# Get request results
Note.request "every_notes", (err, notes) ->
    console.log notes

# Destroy documents through request results
Note.requestDestroy "every_notes", {key: ids[3]}, (err) ->

# Remove request
Note.removeRequest "every_notes", (err) ->
     console.log err
```

### Accounts

```coffeescript
# Create
dataMailBox =
    name: "test mailBox"
    id: "110"
MailBox.create dataMailBox, (err, mailBox) =>
    dataAccount =
        pwd: "password"
        login: "log"
    mailBox.createAccount dataAccount, (err, account) ->
        console.log account.id

# Get
mailBox.getAccount (err, account) ->
    console.log account

# Update
data =
    pwd: "newPassword"
    login: "newLog"
mailBox.updateAccount data, (err) ->
    console.log err

# Update attributes
mailBox.mergeAccount login: "newLog", (err) ->
    console.log err

# Delete
mailBox.destroy (err) ->
    console.log err
```

## Build & tests

To build source to JS, run

    cake build

To run tests:

    cake tests

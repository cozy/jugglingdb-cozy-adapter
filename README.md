## About

*cozy-jugglindb-data* is an adapter for
[JugglingDB](https://github.com/1602/jugglingdb "JugglingDB") required by
cozy applications to use the Cozy Data System.

## Setup for RailwayJS

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

```coffeescript

### Documents ###

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


### Indexation ###

# Index document fields
note.index ["title", "content"], (err) ->
    console.log err

# Search through indexes
Note.search "dragons", (err, notes) ->
    console.log notes


### Files ###

# Attach file
note.attachFile "./test.png", (err) ->
    console.log err

# Get file
stream = @note.getFile "test.png", (err) ->
     console.log err
stream.pipe fs.createWriteStream('./test-get.png')


### Requests ###

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

### Account ###

# Existence
MailBox.existAccount 123, (err, isExist) ->
    console.log isExist

# Find
MailBox.findAccount 321, (err, account) ->
    console.log account

# Create
data =
    login: "log"
    pwd: "password"
    service: "cozyCloud"
MailBox.createAccount data, (err, account) ->
    console.log account.id

# Update
account.saveAccount (err) ->
    console.log err

# Update attributes
account.mergeAccount login: "newLog", (err) ->
    console.log err

# Upsert
MailBox.createOrUpdateAccount @data.id, (err, account) ->
    console.log err

# Delete
account.destroy (err) ->
    console.log err

### Accounts ###

# Initialize keys
Prox.initializeKeys { pwd: "password"}, (err) ->
    console.log err

# Update keys
Prox.updateKeys { pwd: "password"}, (err) ->
    console.log err

# Delete keys
Prox.deleteKeys (err) ->
    console.log err
```

## Build & tests

To build source to JS, run

    cake build

To run tests:

    cake tests

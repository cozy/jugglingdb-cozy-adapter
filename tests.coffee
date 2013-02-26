fs = require("fs")
should = require('chai').Should()
async = require('async')

Client = require("request-json").JsonClient
Schema = require('jugglingdb').Schema

client = new Client "http://localhost:9101/"
schema = new Schema 'memory'
schema.settings = {}
require("./src/cozy_data_system").initialize(schema)

Note = schema.define 'Note',
    title:
        type: String
    content:
        type: Schema.Text
    author:
        type: String

MailBox = schema.define 'MailBox',
    pwd:
        type: String
    login:
        type: String
    service:
        type: String

Prox = schema.define 'Prox'


describe "Existence", ->

    before (done) ->
        client.post 'data/321/', value: "created value", \
            (error, response, body) ->
            done()

    after (done) ->
        client.del "data/321/", (error, response, body) ->
            done()


    describe "Check Existence of a Document that does not exist in database", ->

        it "When I check existence of Document with id 123", \
                (done) ->
            Note.exists 123, (err, isExist) =>
                should.not.exist err
                @isExist = isExist
                done()

        it "Then false should be returned", ->
            @isExist.should.not.be.ok

    describe "Check Existence of a Document that does exist in database", ->

        it "When I check existence of Document with id 321", \
                (done) ->
            Note.exists 321, (err, isExist) =>
                should.not.exist err
                @isExist = isExist
                done()

        it "Then true should be returned", ->
            @isExist.should.be.ok


describe "Find", ->

    before (done) ->
        client.post 'data/321/',
            title: "my note"
            content: "my content"
            docType: "Note"
            , (error, response, body) ->
            done()

    after (done) ->
        client.del "data/321/", (error, response, body) ->
            done()


    describe "Find a note that does not exist in database", ->

        it "When I claim note with id 123", (done) ->
            Note.find 123, (err, note) =>
                @note = note
                done()

        it "Then null should be returned", ->
            should.not.exist @note

    describe "Find a note that does exist in database", ->

        it "When I claim note with id 321", (done) ->
            Note.find 321, (err, note) =>
                @note = note
                done()

        it "Then I should retrieve my note ", ->
            should.exist @note
            @note.title.should.equal "my note"
            @note.content.should.equal "my content"


describe "Create", ->

    before (done) ->
        client.post 'data/321/', {
            title: "my note"
            content: "my content"
            docType: "Note"
            } , (error, response, body) ->
            done()

    after (done) ->
        client.del "data/321/", (error, response, body) ->
            client.del "data/987/", (error, response, body) ->
                done()

    describe "Try to create a Document existing in Database", ->
        after ->
            @err = null
            @note = null

        it "When create a document with id 321", (done) ->
            Note.create { id: "321", "content":"created value"}, (err, note) =>
                @err = err
                @note = note
                done()

        it "Then an error is returned", ->
            should.exist @err

    describe "Create a new Document with a given id", ->

        before ->
            @id = "987"

        after ->
            @err = null
            @note = null

        it "When I create a document with id 987", (done) ->
            Note.create { id: @id, "content": "new note" }, (err, note) =>
                @err = err
                @note = note
                done()

        it "Then this should be set on document", ->
            should.not.exist @err
            should.exist @note
            @note.id.should.equal @id

        it "And the Document with id 987 should exist in Database", (done) ->
            Note.exists  @id, (err, isExist) =>
                should.not.exist err
                isExist.should.be.ok
                done()

        it "And the Document in DB should equal the sent Document", (done) ->
            Note.find  @id, (err, note) =>
                should.not.exist err
                note.id.should.equal @id
                note.content.should.equal "new note"
                done()


    describe "Create a new Document without an id", ->

        before ->
            @id = null

        after (done) ->
            @note.destroy =>
                @err = null
                @note = null
                done()

        it "When I create a document without an id", (done) ->
            Note.create { "title": "cool note", "content": "new note" }, (err, note) =>
                @err = err if err
                @note = note
                done()

        it "Then the id of the new Document should be returned", ->
            should.not.exist @err
            should.exist @note.id
            @id = @note.id

        it "And the Document should exist in Database", (done) ->
            Note.exists  @id, (err, isExist) =>
                should.not.exist err
                isExist.should.be.ok
                done()

        it "And the Document in DB should equal the sent Document", (done) ->
            Note.find  @id, (err, note) =>
                should.not.exist err
                note.id.should.equal @id
                note.content.should.equal "new note"
                done()



describe "Update", ->

    before (done) ->
        data =
            title: "my note"
            content: "my content"
            docType: "Note"

        client.post 'data/321/', data, (error, response, body) ->
            done()
        @note = new Note data

    after (done) ->
        client.del "data/321/", (error, response, body) ->
            done()


    describe "Try to Update a Document that doesn't exist", ->
        after ->
            @err = null

        it "When I update a document with id 123", (done) ->
            @note.id = "123"
            @note.save (err) =>
                @err = err
                done()

        it "Then an error is returned", ->
            should.exist @err

    describe "Update a Document", ->

        it "When I update document with id 321", (done) ->
            @note.id = "321"
            @note.title = "my new title"
            @note.save (err) =>
                @err = err
                done()

        it "Then no error is returned", ->
            should.not.exist @err

        it "And the old document must have been replaced in DB", (done) ->
            Note.find @note.id, (err, updatedNote) =>
                should.not.exist err
                updatedNote.id.should.equal "321"
                updatedNote.title.should.equal "my new title"
                done()


describe "Update attributes", ->

    before (done) ->
        data =
            title: "my note"
            content: "my content"
            docType: "Note"

        client.post 'data/321/', data, (error, response, body) ->
            done()
        @note = new Note data

    after (done) ->
        client.del "data/321/", (error, response, body) ->
            done()


    describe "Try to update attributes of a document that doesn't exist", ->
        after ->
            @err = null

        it "When I update a document with id 123", (done) ->
            @note.updateAttributes title: "my new title", (err) =>
                @err = err
                done()

        it "Then an error is returned", ->
            should.exist @err

    describe "Update a Document", ->

        it "When I update document with id 321", (done) ->
            @note.id = "321"
            @note.updateAttributes title: "my new title", (err) =>
                @err = err
                done()

        it "Then no error is returned", ->
            should.not.exist @err

        it "And the old document must have been replaced in DB", (done) ->
            Note.find @note.id, (err, updatedNote) =>
                should.not.exist err
                updatedNote.id.should.equal "321"
                updatedNote.title.should.equal "my new title"
                done()



describe "Upsert attributes", ->

    after (done) ->
        client.del "data/654/", (error, response, body) ->
            done()

    describe "Upsert a non existing document", ->
        it "When I upsert document with id 654", (done) ->
            @data =
                id: "654"
                title: "my note"
                content: "my content"

            Note.updateOrCreate @data, (err) =>
                @err = err
                done()

        it "Then no error should be returned.", ->
            should.not.exist @err

        it "Then the document with id 654 should exist in Database", (done) ->
            Note.find @data.id, (err, updatedNote) =>
                should.not.exist err
                updatedNote.id.should.equal "654"
                updatedNote.title.should.equal "my note"
                done()

    describe "Upsert an existing Document", ->

        it "When I upsert document with id 654", (done) ->
            @data =
                id: "654"
                title: "my new title"

            Note.updateOrCreate @data, (err, note) =>
                should.not.exist note
                @err = err
                done()

        it "Then no data should be returned", ->
            should.not.exist @err

        it "Then the document with id 654 should be updated", (done) ->
            Note.find @data.id, (err, updatedNote) =>
                should.not.exist err
                updatedNote.id.should.equal "654"
                updatedNote.title.should.equal "my new title"
                done()


describe "Delete", ->
    before (done) ->
        client.post 'data/321/', {
            title: "my note"
            content: "my content"
            docType: "Note"
            } , (error, response, body) ->
            done()

    after (done) ->
        client.del "data/321/", (error, response, body) ->
            client.del "data/987/", (error, response, body) ->
                done()


    describe "Deletes a document that is not in Database", ->

        it "When I delete Document with id 123", (done) ->
            note = new Note id:123
            note.destroy (err) =>
                @err = err
                done()

        it "Then an error should be returned", ->
            should.exist @err

    describe "Deletes a document from database", ->

        it "When I delete document with id 321", (done) ->
            note = new Note id:321
            note.destroy (err) =>
                @err = err
                done()

        it "Then no error is returned", ->
            should.not.exist @err

        it "And Document with id 321 shouldn't exist in Database", (done) ->
            Note.exists 321, (err, isExist) =>
                isExist.should.not.be.ok
                done()


### Indexation ###

ids = []
createNoteFunction = (title, content, author) ->
    (callback) ->
        if author? then authorId = author.id else authorId = null
        data =
            title: title
            content: content
            author: authorId

        Note.create data, (err, note) ->
            ids.push note.id
            note.index ["title", "content"], (err) ->
                callback()

createTaskFunction = (description) ->
    (callback) ->
        client.post 'data/', {
            description: "description"
            docType: "task"
        } , (error, response, body) ->
            callback()



deleteNoteFunction = (id) ->
    (callback) ->
        client.del "data/#{id}/", (err) -> callback()

describe "Search features", ->

    before (done) ->
        client.post 'data/321/', {
            title: "my note"
            content: "my content"
            docType: "Note"
            } , (error, response, body) ->
                done()

    after (done) ->
        funcs = []
        for id in ids
            funcs.push deleteNoteFunction(id)
        async.series funcs, ->
            ids = []
            done()

    describe "index", ->

        before (done) ->
            client.del "data/index/clear-all/", (err, response) ->
                done()

        it "Given I index four notes", (done) ->
            async.series [
                createNoteFunction "Note 01", "little stories begin"
                createNoteFunction "Note 02", "great dragons are coming"
                createNoteFunction "Note 03", "small hobbits are afraid"
                createNoteFunction "Note 04", "such as humans"
            ], ->
                done()

        it "When I send a request to search the notes containing dragons", (done) ->
            Note.search "dragons", (err, notes) =>
                @notes = notes
                done()

        it "Then result is the second note I created", ->
            @notes.length.should.equal 1
            @notes[0].title.should.equal "Note 02"
            @notes[0].content.should.equal "great dragons are coming"


### Attachments ###

describe "Attachments", ->

    before (done) ->
        @note = new Note id: 321
        data =
            title: "my note"
            content: "my content"
            docType: "Note"

        client.post 'data/321/', data, (error, response, body) ->
            done()

    after (done) ->
        client.del "data/321/", (error, response, body) ->
            done()

    describe "Add an attachment", ->

        it "When I add an attachment", (done) ->
            @note.attachFile "./test.png", (err) =>
                @err = err
                done()

        it "Then no error is returned", ->
            should.not.exist @err

    describe "Retrieve an attachment", ->

        it "When I claim this attachment", (done) ->
            stream = @note.getFile "test.png", -> done()
            stream.pipe fs.createWriteStream('./test-get.png')

        it "I got the same file I attached before", ->
            fileStats = fs.statSync('./test.png')
            resultStats = fs.statSync('./test-get.png')
            resultStats.size.should.equal fileStats.size

    describe "Remove an attachment", ->

        it "When I remove this attachment", (done) ->
            @note.removeFile "test.png", (err) =>
                @err = err
                done()

        it "Then no error is returned", ->
            should.not.exist @err

        it "When I claim this attachment", (done) ->
            stream = @note.getFile "test.png", (err) =>
                @err = err
                done()
            stream.pipe fs.createWriteStream('./test-get.png')

        it "I got an error", ->
            should.exist @err


checkNoError = ->
    it "Then no error should be returned", ->
        should.not.exist @err


checkError = ->
    it "Then error should be returned", ->
        should.exist  @err

describe "Requests", ->

    before (done) ->
        async.series [
            createNoteFunction "Note 01", "little stories begin"
            createNoteFunction "Note 02", "great dragons are coming"
            createNoteFunction "Note 03", "small hobbits are afraid"
            createNoteFunction "Note 04", "such as humans"
            createTaskFunction "Task 01"
            createTaskFunction "Task 02"
            createTaskFunction "Task 03"
        ], ->
            done()

    after (done) ->
        funcs = []
        for id in ids
            funcs.push deleteNoteFunction(id)
        async.series funcs, ->
            ids = []
            done()

    describe "index", ->
    describe "View creation", ->

        describe "Creation of the first view + design document creation", ->

            it "When I send a request to create view every_docs", (done) ->
                delete @err
                @map = (doc) ->
                    emit doc._id, doc
                    return
                Note.defineRequest "every_notes", @map, (err) ->
                    should.not.exist err
                    done()

            checkNoError()

    describe "Access to a view without option", ->

        describe "Access to a non existing view", ->

            it "When I send a request to access view dont-exist", (done) ->
                delete @err
                Note.request "dont-exist", (err, notes) =>
                    @err = err
                    should.exist err
                    done()

            checkError()


        describe "Access to an existing view : every_notes", (done) ->

            it "When I send a request to access view every_docs", (done) ->
                delete @err
                Note.request "every_notes", (err, notes) =>
                    @notes = notes
                    done()

            it "Then I should have 4 documents returned", ->
                @notes.should.have.length 4

        describe "Access to a doc from a view : every_notes", (done) ->

            it "When I send a request to access doc 3 from every_docs", (done) ->
                delete @err
                Note.request "every_notes", {key: ids[3]}, (err, notes) =>
                    @notes = notes
                    done()

            it "Then I should have 1 documents returned", ->
                @notes.should.have.length 1
                @notes[0].id.should.equal ids[3]

    describe "Deletion of docs through requests", ->

        describe "Delete a doc from a view : every_notes", (done) ->

            it "When I send a request to delete a doc from every_docs", (done) ->
                Note.requestDestroy "every_notes", {key: ids[3]}, (err) ->
                    should.not.exist err
                    done()

            it "And I send a request to access view every_docs", (done) ->
                delete @err
                delete @notes
                Note.request "every_notes", {key: ids[3]}, (err, notes) =>
                    @notes = notes
                    done()

            it "Then I should have 0 documents returned", ->
                @notes.should.have.length 0

            it "And other documents are still there", (done) ->
                Note.request "every_notes", (err, notes) =>
                    should.not.exist err
                    notes.should.have.length 3
                    done()

        describe "Delete all doc from a view : every_notes", (done) ->

            it "When I delete all docs from every_docs", (done) ->
                Note.requestDestroy "every_notes", (err) ->
                    should.not.exist err
                    done()

            it "And I send a request to grab all docs from every_docs", (done) ->
                delete @err
                delete @notes
                Note.request "every_notes", (err, notes) =>
                    @notes = notes
                    done()

            it "Then I should have 0 documents returned", ->
                @notes.should.have.length 0

    describe "Deletion of an existing view", ->

        it "When I send a request to delete view every_notes", (done) ->
            Note.removeRequest "every_notes", (err) ->
                should.not.exist err
                done()

        it "And I send a request to access view every_notes", (done) ->
            delete @err
            Note.request "every_notes", (err, note) =>
                @err = err
                done()

        checkError()

#### Relations ###

#describe "Relations", ->

    #before (done) ->
        #Author.create name: "John", (err, author) =>
            #@author = author
            #async.series [
                #createNoteFunction "Note 01", "little stories begin", author
                #createNoteFunction "Note 02", "great dragons are coming", author
                #createNoteFunction "Note 03", "small hobbits are afraid", author
                #createNoteFunction "Note 04", "such as humans", null
            #], ->
                #done()

    #after (done) ->
        #funcs = []
        #for id in ids
            #funcs.push deleteNoteFunction(id)
        #async.series funcs, ->
            #ids = []
            #if author?
                #@author.destroy ->
                    #done()
            #else
                #done()

    #describe "Has many relation", ->

        #it "When I require all notes related to given author", (done) ->
            #@author.notes (err, notes) =>
                #should.not.exist err
                #@notes = notes
                #done()

        #it "Then I have three notes", ->
            #should.exist @notes
            #@notes.length.should.equal 3###


### Account ###

describe "Initialize keys", ->

    before (done) ->
        data =
            email: "user@CozyCloud.CC"
            timezone: "Europe/Paris"
            password: "pwd_user"
            docType: "User"
        client.post 'data/102/', data, (err, res, body) =>
            done()

    it "When I initialize keys", (done) ->
        Prox.initializeKeys "password", (err) =>
            @err = err
            done()

    it "Then no error is returned", ->
        should.not.exist @err

describe "Update keys", ->

    it "When I update keys", (done) ->
        Prox.updateKeys "newPassword", (err) =>
            @err = err
            done()

    it "Then no error is returned", ->
        should.not.exist @err

describe "Delete keys", ->

    it "When I delete keys", (done) ->
        Prox.deleteKeys (err) =>
            @err = err
            done()

    it "Then no error is returned", ->
        should.not.exist @err

describe "Initialize keys in a second connexion", ->

    it "When I initialize keys", (done) ->
        Prox.initializeKeys "password", (err) =>
            @err = err
            done()

    it "Then no error is returned", ->
        should.not.exist @err


describe "Create an account", ->

    after (done) ->
        client.del "account/123/", (err, res) ->
                done()

    describe "Create an account without id", ->

        it "When I create an account without id", (done) ->
            data =
                pwd: "password"
                login: "log"
                service: "CozyCloud"
            MailBox.createAccount data, (err, account) =>
                should.not.exist err
                @account = account
                done()

        it "Then id of account should be returned", ->
            should.exist @account.id
            @id = @account.id

        it "And account should be in the database", ->
            Note.exists @id, (err, isExist) =>
                should.not.exist err
                isExist.should.be.equal true

        it "And password should be encrypted", (done) ->
            Note.find @id, (err, note) =>
                should.not.exist err
                should.exist note.pwd
                note.pwd.should.be.not.equal "password"

    describe "Create an account with a specific id", ->

        it "When I create an account with id 123", (done) ->
            data =
                id: "123"
                pwd: "password"
                login: "log"
                service: "CozyCloud"
            MailBox.createAccount data, (err, account) =>
                should.not.exist err
                @account = account
                done()

        it "Then id 123 should be returned", ->
            should.exist @account.id
            @account.id should.be.equal "123"

        it "And account should be in the database", ->
            Note.exists 123, (err, isExist) =>
                should.not.exist err
                isExist.should.be.equal true

        it "And password should be encrypted", (done) ->
            Note.find @id, (err, note) =>
                should.not.exist err
                should.exist note.pwd
                note.pwd.should.be.not.equal "password"

    describe "Try to create an account without field 'pwd' ", ->
        after ->
            @err = null

        it "When I try to create an account", (done) ->
            data =
                login: "log"
                service: "CozyCloud"
            MailBox.createAccount data, (err, account) =>
                @err = err
                @account = account
                done()

        it "Then error should be returned", ->
            should.exist @err

        it "And account should not exist", ->
            should.not.exist @account

    describe "Try to create an account that exist in database", ->
        after ->
            @err = null

        it "When I try to create account with id 123", (done) ->
            data =
                id: "123"
                pwd: "password"
                login: "log"
                service: "CozyCloud"
            MailBox.createAccount data, (err, account) =>
                @err = err
                @account = account
                done()

        it "The error should be returned", ->
            should.exist @err


describe "Find an account", ->

    before (done) ->
        data =
            pwd: "password"
            login: "log"
            service: "cozyCLoud"
        client.post 'account/123/', data, (err, res, body) ->
            done()

    after (done) ->
        client.del "account/123/", (err, res) ->
                done()

    describe "Try to find an account that doesn't exist", ->

        it "When I find account with id 456", (done) ->
            MailBox.findAccount 456, (err, account) =>
                @account = account
                done()

        it "Then null should ne returned", ->
            should.not.exist @account

    describe "Find an account that exist in the database", ->
        it "When I find account with id 123", (done) ->
            MailBox.findAccount 123, (err, account) =>
                @err = err
                @account = account
                done()

        it "Then no error should be returned", ->
            should.not.exist @err

        it "And account should be returned", ->
            should.exist @account
            res =
                id: "123"
                pwd: "password"
                login: "log"
                service: "CozyCloud"
                docType: "Account"
            @account.should.be.deep.equal res


describe "Existence of an account", ->

    before (done) ->
        data =
            pwd: "password"
            login: "log"
            service: "cozyCLoud"
        client.post 'account/123/', data, (err, res, body) ->
            done()

    after (done) ->
        client.del "account/123/", (err, res) ->
                done()

    describe "Check existence of an account that exists in the database", ->

        it "When I check the existence of account with id 123", (done) ->
            MailBox.existAccount 123, (err, isExist) =>
                @err = err
                @isExist = isExist
                done()

        it "Then no error should be returned", ->
            should.not.exist @err

        it "And response should be positive", ->
            @isExist.should.be.equal true

    describe "Check existence of an account that doesn't exist in the DB", ->

        it "When I check the existence of account with id 456", (done) ->
            MailBox.existAccount 456, (err, isExist) =>
                @err = err
                @isExist = isExist
                done()

        it "Then no error should be returned", ->
            should.not.exist @err

        it "And response should be negative", ->
            isExist.should.be.equal false

describe "Update an account", ->

    before (done) ->
        data =
            pwd: "password"
            login: "log"
            service: "cozyCloud"

        client.post 'account/123/', data, (err, res, body) ->
            done()
        @account = new Account data

    after (done) ->
        client.del "account/123/", (err, res) ->
            done()

    describe "Update an account that doesn't exist", ->
        after ->
            @err = null

        it "When I update account with id 456", (done) ->
            @account.id = "456"
            @account.save (err) =>
                @err = err
                done()

        it "Then error should be returned", ->
            should.exist @err

    describe "Update an account that exist with 'pwd'", ->
        it "When I update account with id 123 with a field 'pwd' ", (done)->
            @account.id = "123"
            @account.pwd = "newPassword"
            @account.login = "newLog"
            @account.service = "newService"
            @accout.save (err) =>
                @err = err
                done()

        it "Then no error should be returned", ->
            should.not.exist @err

        it "And account should be updated", (done) ->
            MailBox.findAccount 123, (err, updatedAccount) =>
                should.not.exist err
                should.exist updatedAccount.pwd
                updatedAccount.pwd.should.be.equal "newPassword"
                updatedAccount.login.should.be.equal "newLog"
                updatedAccount.service.should.be.equal "newService"
                done()

    describe "Try to update an account sithout field 'pwd'", ->

        it "When I try to update account with id 123", (done) ->
            @account.id = "123"
            @account.login = "newLog"
            @account.service = "newService"
            @accout.save (err) =>
                @err = err
                done()

        it "Then error should be returned", ->
            should.exist @err


describe "Merge an account", ->

    before (done) ->
        data =
            pwd: "password"
            login: "log"
            service: "cozyCloud"

        client.post 'account/123/', data, (err, res, body) ->
            done()
        @account = new Account data

    after (done) ->
        client.del "account/123/", (err, res, body) ->
            done()

    describe "Merge an account that doesn't exist", ->
        after ->
            @err = null

        it "When I merge account with id 456", (done) ->
            @account.id = "456"
            @account.mergeAccount login: "newLog", (err) =>
                @err = err
                done()

        it "Then an error should be returned", ->
            should.exist @err

    describe "Merge an account that exists", ->

        it "When I merge account with id 123", (done) ->
            @account.id = "123"
            @account.mergeAccount login: "newLog", (err) =>
                @err = err
                done()

        it "Then no error should be returned", ->
            should.not.exist @err

        it "And account should be replaced", (done) ->
            MailBox.findAccount 123, (err, account) =>
                should.not.exist err
                should.exist account
                account.pwd.should.be.equal "password"
                account.login.should.be.equal "newLog"
                account.service.should.be.equal "cozyCloud"
                done()


descibe "Upsert", ->

    after (done) ->
        client.del "account/789/", (error, response, body) ->
            done()

    describe "Upsert an account that doesn't exist", ->

        it "When I upsert account with id 789", (done) ->
            @data =
                id: "789"
                pwd: "password"
                login: "log"
                service: "cozyCloud"
            Account.updateOrCreateAccount @data, (err) =>
                @err = err
                done()

        it "Then no error should be returned", ->
            should.not.exist @err

        it "And account with id 789 exists", (done) ->
            Account.findAccount 789, (err, updatedAccount) =>
                should.not.exist err
                should exist updatedAccount
                updatedAccount.pwd.should.be.equal "password"
                updatedAccount.login.should.be.equal "log"
                updatedAccount.service.should.be.equal "cozyCloud"
                done()

    describe "Upsert an account that exists", ->

        it "When I upsert account with id 789", (done) ->
            @data =
                id: "789"
                pwd: "newPassword"
                login: "newLog"
                service: "cozyCloud789"
            Account.updateOrCreateAccount @data, (err) =>
                @err = err
                done()

        it "Then no error should be returned", ->
            should.not.exist @err

        it "And account with id 789 exists", (done) ->
            Account.findAccount 789, (err, updatedAccount) =>
                should.not.exist err
                should exist updatedAccount
                updatedAccount.pwd.should.be.equal "newPassword"
                updatedAccount.login.should.be.equal "newLog"
                updatedAccount.service.should.be.equal "cozyCloud789"
                done()

describe "Delete an account", ->
    before (done) ->
        data =
            pwd: "password"
            login: "log"
            service: "cozyCLoud"
        client.post 'account/123/', data, (err, res, body) ->
            done()

    after (done) ->
        client.del "account/123/", (err, res) ->
                done()

    describe "Delete an account that doesn't exist", ->

        it "When I delete Document with id 456", (done) ->
            account = new Account id:456
            account.destroy (err) =>
                @err = err
                done()

        it "Then an error should be returned", ->
            should.exist @err

    describe "Delete an account that exist", ->

        it "When I delete document with id 123", (done) ->
            account = new Account id:123
            account.destroy (err) =>
                @err = err
                done()

        it "Then no error is returned", ->
            should.not.exist @err

        it "And account with id 321 shouldn't exist in Database", (done) ->
            Account.exists 123, (err, isExist) =>
                isExist.should.not.be.ok
                done()
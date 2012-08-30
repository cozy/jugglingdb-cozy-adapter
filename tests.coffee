should = require('chai').Should()
async = require('async')
Client = require("request-json").JsonClient


client = new Client "http://localhost:7000/"

Schema = require('jugglingdb').Schema
schema = new Schema 'memory'
require("./src/cozy_data_system").initialize(schema)

Note = schema.define 'Note',
    title:     { type: String, length: 255 }
    content:   { type: Schema.Text }


describe "Existence", ->

    before (done) ->
        client.post 'data/321/', {"value":"created value"}, \
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

        after ->
            @err = null
            @note = null

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


should = require('chai').Should()
async = require('async')
Client = require("request-json").JsonClient


client = new Client "http://localhost:7000/"

Schema = require('jugglingdb').Schema
schema = new Schema 'memory'
require("./src/cozy_data_system").initialize(schema)

Note = schema.define 'Post',
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



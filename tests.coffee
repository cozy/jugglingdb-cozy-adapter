should = require('chai').Should()
async = require('async')
{CozyDataSystem} = require("./src/cozy_data_system")


adapter = new CozyDataSystem()

describe "Existence", ->

    describe "Check Existence of a Document that does not exist in database", ->

        it "When I check existence of Document with id 123", \
                (done) ->
            adapter.exists Note, id, (err, isExist) ->
                should.not.exist err
                @isExist = isExist
                done()

        it "Then false should be returned", ->
            @isExist.should.not.be.ok

    describe "Check Existence of a Document that does exist in database", ->

        it "When I check existence of Document with id 123", \
                (done) ->
            adapter.exists Note, id, (err, isExist) ->
                should.not.exist err
                @isExist = isExist
                done()

        it "Then false should be returned", ->
            @isExist.should.be.ok



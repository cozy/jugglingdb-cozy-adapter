Client = require("request-json").JsonClient

exports.initialize = (schema, callback) ->
  schema.adapter = new exports.CozyDataSystem()
  process.nextTick(callback)


class exports.CozyDataSystem

    constructor: ->
        @_models = {}
        @client = new Client "http://localhost:7000/"

    define: (descr) ->
        @_models[descr.model.modelName] = descr

    exists: (model, id, callback) =>
        @client.get "data/exist/#{id}/", (error, response, body) =>
            if error
                callback error
            else if not body? or not body.exist?
                callback new Error("Data system returned invalid data.")
            else
                callback null, body.exist

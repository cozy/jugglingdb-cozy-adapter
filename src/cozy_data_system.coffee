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

    find: (model, id, callback) =>
         @client.get "data/#{id}/", (error, response, body) =>
            if error
                callback error
            else if response.statusCode == 404
                callback null, null
            else if body.docType != model
                callback null, null
            else
                callback null, new @_models[model].model(body)

    create: (model, data, callback) =>
        path = "data/"
        if data.id?
            path += "#{data.id}/"
            delete data.id
        data.docType = model
        @client.post path, data, (error, response, body) =>
            if error
                callback error
            else if response.statusCode == 409
                callback new Error("This document already exists")
            else if response.statusCode != 201
                callback new Error("Server error occured.")
            else
                callback null, body._id

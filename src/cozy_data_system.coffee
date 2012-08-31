Client = require("request-json").JsonClient

exports.initialize = (schema, callback) ->
  schema.adapter = new exports.CozyDataSystem()
  process.nextTick(callback)


class exports.CozyDataSystem

    constructor: ->
        @_models = {}
        @client = new Client "http://localhost:7000/"

    # Register Model to adapter
    define: (descr) ->
        @_models[descr.model.modelName] = descr

    # Check existence of model in the data system.
    exists: (model, id, callback) =>
        @client.get "data/exist/#{id}/", (error, response, body) =>
            if error
                callback error
            else if not body? or not body.exist?
                callback new Error("Data system returned invalid data.")
            else
                callback null, body.exist

    # Find a doc with its ID. Returns it if it is found else it
    # returns null
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

    # Create a new document from given data. If no ID is set a new one
    # is automatically generated.
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

    # Save all model attributes to DB.
    save: (model, data, callback) ->
        data.docType = model
        @client.put "data/#{data.id}/", data, (error, response, body) =>
            if error
                callback error
            else if response.statusCode == 404
                callback new Error("Document not found")
            else if response.statusCode != 200
                callback new Error("Server error occured.")
            else
                callback()

    # Save only given attributes to DB.
    updateAttributes: (model, id, data, callback) ->
        @client.put "data/merge/#{id}/", data, (error, response, body) =>
            if error
                callback error
            else if response.statusCode == 404
                callback new Error("Document not found")
            else if response.statusCode != 200
                callback new Error("Server error occured.")
            else
                callback()

    # Save only given attributes to DB. If model does not exist it is created.
    # It requires an ID.
    updateOrCreate: (model, data, callback) ->
        data.docType = model
        @client.put "data/upsert/#{data.id}/", data, (error, response, body) =>
            if error
                callback error
            else if response.statusCode != 200 and response.statusCode != 201
                callback new Error("Server error occured.")
            else if response.statusCode == 200
                callback null
            else if response.statusCode == 201
                callback null, body._id


    # Destroy model in database.
    # Call method like this:
    #     note = new Note id: 123
    #     note.destroy ->
    #         ...
    destroy: (model, id, callback) =>
        @client.del "data/#{id}/", (error, response, body) =>
            if error
                callback error
            else if response.statusCode == 404
                callback new Error("Document not found")
            else if response.statusCode != 204
                callback new Error("Server error occured.")
            else
                callback()



Client = require("request-json").JsonClient
fs = require 'fs'
util = require 'util'

dataSystemHost = process.env.DATASYSTEM_HOST or 'localhost'
dataSystemPort = process.env.DATASYSTEM_PORT or '9101'

exports.initialize = (@schema, callback) ->
    unless schema.settings.url?
        schema.settings.url = "http://#{dataSystemHost}:#{dataSystemPort}/"

    schema.adapter = new exports.CozyDataSystem schema
    process.nextTick callback


class exports.CozyDataSystem

    constructor: (@schema) ->
        @_models = {}
        @client = new Client schema.settings.url
        if process.env.NODE_ENV is "production" or
           process.env.NODE_ENV is "test"
            @username = process.env.NAME
            @password = process.env.TOKEN
        else
            @username =  Math.random().toString 36
            @password = "token"


    # Register Model to adapter and define extra methods
    define: (descr) ->
        @_models[descr.model.modelName] = descr
        if @username? and @password?
            @client.setBasicAuth @username, @password

        descr.model.createMany = (dataList, callback) =>
            @createMany descr.model.modelName, dataList, callback
        descr.model.search = (options, callback) =>
            @search descr.model.modelName, options, callback
        descr.model.defineRequest = (name, map, callback) =>
            @defineRequest descr.model.modelName, name, map, callback
        descr.model.request = (name, params, callback) =>
            @request descr.model.modelName, name, params, callback
        descr.model.rawRequest = (name, params, callback) =>
            @rawRequest descr.model.modelName, name, params, callback
        descr.model.removeRequest = (name, callback) =>
            @removeRequest descr.model.modelName, name, callback
        descr.model.requestDestroy = (name, params, callback) =>
            @requestDestroy descr.model.modelName, name, params, callback
        descr.model.all = (params, callback) =>
            @all descr.model.modelName, params, callback
        descr.model.destroyAll = (params, callback) =>
            @destroyAll descr.model.modelName, params, callback
        descr.model.applyRequest = (params, callback) =>
            @applyRequest descr.model.modelName, params, callback
        descr.model._forDB = (data) =>
            @_forDB descr.model.modelName, data
        descr.model::index = (fields, callback) ->
            @_adapter().index @, fields, callback
        descr.model::attachFile = (path, data, callback) ->
            @_adapter().attachFile  @, path, data, callback
        descr.model::getFile = (path, callback) ->
            @_adapter().getFile  @, path, callback
        descr.model::saveFile = (path, filePath, callback) ->
            @_adapter().saveFile  @, path, filePath, callback
        descr.model::removeFile = (path, callback) ->
            @_adapter().removeFile  @, path, callback
        descr.model::attachBinary = (path, data, callback) ->
            @_adapter().attachBinary  @, path, data, callback
        descr.model::getBinary = (path, callback) ->
            @_adapter().getBinary  @, path, callback
        descr.model::saveBinary = (path, filePath, callback) ->
            @_adapter().saveBinary  @, path, filePath, callback
        descr.model::removeBinary = (path, callback) ->
            @_adapter().removeBinary  @, path, callback

    # Check existence of model in the data system.
    exists: (model, id, callback) ->
        @client.get "data/exist/#{id}/", (error, response, body) =>
            if error
                callback error
            else if not body? or not body.exist?
                callback new Error "Data system returned invalid data."
            else
                callback null, body.exist

    # Find a doc with its ID. Returns it if it is found else it
    # returns null
    find: (model, id, callback) ->
        @client.get "data/#{id}/", (error, response, body) =>
            if error
                callback error
            else if response.statusCode is 404
                callback null, null
            else if body.docType.toLowerCase() isnt model.toLowerCase()
                callback null, null
            else
                callback null, new @_models[model].model body


    # Create a new document from given data. If no ID is set a new one
    # is automatically generated.
    create: (model, data, callback) ->
        path = "data/"
        if data.id?
            path += "#{data.id}/"
            delete data.id
        data.docType = model

        @client.post path, data, (error, response, body) ->
            if error
                callback error
            else if response.statusCode is 409
                callback new Error "This document already exists"
            else if response.statusCode isnt 201
                callback new Error "Server error occured."
            else
                callback null, body._id


    # Create a list of documents sequentially.
    createMany: (model, dataList, callback) ->
        ids = []
        (recCreate = =>
            if dataList.length is 0
                callback null, ids.reverse()
            else
                data = dataList.pop()
                @create model, data, (err, id) ->
                    if err then callback err
                    else
                        ids.push id
                        recCreate()
        )()


    # Save all model attributes to DB.
    save: (model, data, callback) ->
        data.docType = model
        @client.put "data/#{data.id}/", data, (error, response, body) ->
            if error
                callback error
            else if response.statusCode is 404
                callback new Error "Document not found"
            else if response.statusCode isnt 200
                callback new Error "Server error occured."
            else
                callback()


    # Save only given attributes to DB.
    updateAttributes: (model, id, data, callback) ->
        @client.put "data/merge/#{id}/", data, (error, response, body) ->
            if error
                callback error
            else if response.statusCode is 404
                callback new Error "Document not found"
            else if response.statusCode isnt 200
                callback new Error "Server error occured."
            else
                callback()


    # Save only given attributes to DB. If model does not exist it is created.
    # It requires an ID.
    updateOrCreate: (model, data, callback) ->
        data.docType = model
        @client.put "data/upsert/#{data.id}/", data, (error, response, body) ->
            if error
                callback error
            else if response.statusCode isnt 200 and
            response.statusCode isnt 201
                callback new Error "Server error occured."
            else if response.statusCode is 200
                callback null
            else if response.statusCode is 201
                callback null, body._id


    # Destroy model in database.
    # Call method like this:
    #     note = new Note id: 123
    #     note.destroy ->
    #         ...
    destroy: (model, id, callback) ->
        @client.del "data/#{id}/", (error, response, body) ->
            if error
                callback error
            else if response.statusCode is 404
                callback new Error "Document not found"
            else if response.statusCode isnt 204
                callback new Error "Server error occured."
            else
                callback()


    # index given fields of model instance inside cozy data indexer.
    # it requires that note is saved before indexing, else it won't work
    # properly (it took data from db).
    # ex: note.index ["content", "title"], (err) ->
    #  ...
    #
    index: (model, fields, callback) ->
        data =
            fields: fields
        @client.post "data/index/#{model.id}", data, ((error, response, body) ->
            if error
                callback error
            else if response.statusCode isnt 200
                callback new Error util.inspect body
            else
                callback null
            ), false


    # Retrieve note through index. Give a query then grab results.
    # ex: Note.search "dragon", (err, docs) ->
    # ...
    #
    search: (model, options, callback) ->

        # ensures backward compatibility
        if typeof options is "string"
            query = options
            numPage = 1
            numByPage = 10
        else
            query = options.query
            numPage = options.numPage or 1
            numByPage = options.numByPage or 10

        data = {query, numPage, numByPage}

        @client.post "data/search/#{model.toLowerCase()}", data, \
                     (error, response, body) =>
            if error
                callback error
            else if response.statusCode isnt 200
                callback new Error util.inspect body
            else
                results = []
                for doc in body.rows
                    results.push new @_models[model].model(doc)
                    doc.id = doc._id if doc._id?
                callback null, results


    # Save a file into data system and attach it to current model.
    attachFile: (model, path, data, callback) ->
        if typeof(data) is "function"
            callback = data
            data = null

        urlPath = "data/#{model.id}/attachments/"
        @client.sendFile urlPath, path, data, (error, response, body) =>
            @checkError error, response, body, 201, callback


    # Get file stream of given file for given model from data system
    getFile: (model, path, callback) ->
        urlPath = "data/#{model.id}/attachments/#{path}"
        @client.get urlPath, (error, response, body) =>
            @checkError error, response, body, 200, callback
        , false


    # Save to disk given file for given model from data system
    saveFile: (model, path, filePath, callback) ->
        urlPath = "data/#{model.id}/attachments/#{path}"
        @client.saveFile urlPath, filePath, (error, response, body) =>
            @checkError error, response, body, 200, callback


    # Remove from db given file of given model.
    removeFile: (model, path, callback) ->
        urlPath = "data/#{model.id}/attachments/#{path}"
        @client.del urlPath, (error, response, body) =>
            @checkError error, response, body, 204, callback


    # Save a file into data system and attach it to current model.
    attachBinary: (model, path, data, callback) ->
        if typeof(data) is "function"
            callback = data
            data = null

        urlPath = "data/#{model.id}/binaries/"
        @client.sendFile urlPath, path, data, (error, response, body) =>
            try
                body = JSON.parse(body)
            @checkError error, response, body, 201, callback


    # Get file stream of given file for given model from data system
    getBinary: (model, path, callback) ->
        urlPath = "data/#{model.id}/binaries/#{path}"
        @client.get urlPath, (error, response, body) =>
            @checkError error, response, body, 200, callback
        , false


    # Save to disk given file for given model from data system
    saveBinary: (model, path, filePath, callback) ->
        urlPath = "data/#{model.id}/binaries/#{path}"
        @client.saveFile urlPath, filePath, (error, response, body) =>
            @checkError error, response, body, 200, callback


    # Remove from db given file of given model.
    removeBinary: (model, path, callback) ->
        urlPath = "data/#{model.id}/binaries/#{path}"
        @client.del urlPath, (error, response, body) =>
            @checkError error, response, body, 204, callback


    # Check if an error occurred. If any, it returns an a proper error.
    checkError: (error, response, body, code, callback) ->
        if error
            callback error
        else if response.statusCode isnt code
            msgStatus = "expected: #{code}, got: #{response.statusCode}"
            msg = "#{msgStatus} -- #{body.error}"
            callback new Error msg
        else
            callback null


    # Create a new couchdb view which is typed with current model type.
    defineRequest: (model, name, request, callback) ->
        if typeof(request) is "function"
            map = request
        else
            map = request.map
            reduce = request.reduce.toString()

        view =
            reduce: reduce
            map: """
        function (doc) {
          if (doc.docType.toLowerCase() === "#{model.toLowerCase()}") {
            filter = #{map.toString()};
            filter(doc);
          }
        }
        """

        path = "request/#{model.toLowerCase()}/#{name.toLowerCase()}/"
        @client.put path, view, (error, response, body) =>
            @checkError error, response, body, 200, callback


    # Return defined request result.
    request: (model, name, params, callback) ->
        callback = params if typeof(params) is "function"

        path = "request/#{model.toLowerCase()}/#{name.toLowerCase()}/"
        @client.post path, params, (error, response, body) =>
            if error
                callback error
            else if response.statusCode isnt 200
                callback new Error util.inspect body
            else
                results = []
                for doc in body
                    doc.value.id = doc.value._id
                    results.push new @_models[model].model(doc.value)
                callback null, results


    # Return defined request result in the format given by data system
    # (couchDB style).
    rawRequest: (model, name, params, callback) ->
        callback = params if typeof(params) is "function"

        path = "request/#{model.toLowerCase()}/#{name.toLowerCase()}/"
        @client.post path, params, (error, response, body) =>
            if error
                callback error
            else if response.statusCode isnt 200
                callback new Error util.inspect body
            else
                callback null, body


    # Delete request that match given name for current type.
    removeRequest: (model, name, callback) ->
        path = "request/#{model.toLowerCase()}/#{name.toLowerCase()}/"
        @client.del path, (error, response, body) =>
            @checkError error, response, body, 204, callback


    # Delete all results that should be returned by the request.
    requestDestroy: (model, name, params, callback) ->
        callback = params if typeof(params) is "function"

        path = "request/#{model.toLowerCase()}/#{name.toLowerCase()}/destroy/"
        @client.put path, params, (error, response, body) =>
            @checkError error, response, body, 204, callback


    # Shortcut for "all" view, a view containing all objects of this type.
    # This method is useful because Juggling make some usage of it for joins.
    # This requires that view all exist for this object.
    all: (model, params, callback) ->
        view = "all"
        if params?.view?
            view = params.view
            delete params.view

        @request model, view, params, callback


    # Shortcut for destroying all documents from "all" view,
    # This requires that view all exist for this object.
    destroyAll: (model, params, callback) ->
        view = "all"
        if params?.view?
            view = params.view
            delete params.view

        @requestDestroy model, view, params, callback


    # Weird rewrite due to a juggling DB on array parsing.
    _forDB: (model, data) ->
        res = {}
        Object.keys(data).forEach (propName) =>
            if @whatTypeName(model, propName) is 'JSON'
                res[propName] = JSON.stringify(data[propName])
            else
                res[propName] = data[propName]
        return res


    # Weird rewrite due to a juggling DB on array parsing.
    whatTypeName: (model, propName) ->
        ds = @schema.definitions[model]
        return ds.properties[propName] && ds.properties[propName].type.name

getClient = (callback) ->
    client = new Client "http://localhost:9101/"
    if process.env.NODE_ENV is "production" or
           process.env.NODE_ENV is "test"
            @username = process.env.NAME
            @password = process.env.TOKEN
        else
            @username =  Math.random().toString(36)
            @password = "token"
    client.setBasicAuth(@username, @password)
    callback client


# Send mail
exports.sendMail = (data, callback) ->
    getClient (client) =>
        path = "mail/"
        client.post path, data, (error, response, body) =>
            if body.error
                callback body.error
            else if response.statusCode is 400
                callback new Error 'Body has not all necessary attributes'
            else if response.statusCode is 500
                callback new Error "Server error occured."
            else
                callback()

# Send mail to user
exports.sendMailToUser = (data, callback) ->
    getClient (client) =>
        path = "mail/to-user/"
        client.post path, data, (error, response, body) =>
            if body.error
                callback body.error
            else if response.statusCode is 400
                callback new Error 'Body has not all necessary attributes'
            else if response.statusCode is 500
                callback new Error "Server error occured."
            else
                callback()

# Send mail from user
exports.sendMailFromUser = (data, callback) ->
    getClient (client) =>
        path = "mail/from-user/"
        client.post path, data, (error, response, body) =>
            if body.error?
                callback body.error
            else if response.statusCode is 400
                callback new Error 'Body has not all necessary attributes'
            else if response.statusCode is 500
                callback new Error "Server error occured."
            else
                callback()

exports.commonRequests =
    checkError: (err) ->
        console.log "An error occured while creating request" if err

    all: -> emit doc._id, doc
    allType: -> emit doc.type, doc
    allSlug: -> emit doc.slug, doc

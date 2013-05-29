Client = require("request-json").JsonClient
fs = require 'fs'

exports.initialize = (@schema, callback) ->
    unless schema.settings.url?
        schema.settings.url = "http://localhost:9101/"

    schema.adapter = new exports.CozyDataSystem schema
    process.nextTick(callback)


class exports.CozyDataSystem

    constructor: (@schema) ->
        @_models = {}
        @client = new Client schema.settings.url
        if process.env.NODE_ENV is "production"
            @username = process.env.name
            @password = process.env.token

    # Register Model to adapter and define extra methods
    define: (descr) ->
        @_models[descr.model.modelName] = descr
        if @username? and @password?
            @client.setBasicAuth(@username, @password)

        descr.model.search = (query, callback) =>
            @search descr.model.modelName, query, callback
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
        descr.model::createAccount = (data, callback) ->
            @_adapter().createAccount @, data, callback
        descr.model::getAccount = (callback) ->
            @_adapter().getAccount @, callback
        descr.model::updateAccount = (data, callback) ->
            @_adapter().updateAccount @, data, callback
        descr.model::mergeAccount = (data, callback) ->
            @_adapter().mergeAccount @, data, callback
        descr.model::destroyAccount = (callback) ->
            @_adapter().destroyAccount @, callback


    # Check existence of model in the data system.
    exists: (model, id, callback) ->
        @client.get "data/exist/#{id}/", (error, response, body) =>
            if error
                callback error
            else if not body? or not body.exist?
                callback new Error("Data system returned invalid data.")
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
            else if body.docType isnt model
                callback null, null
            else
                callback null, new @_models[model].model(body)

    # Create a new document from given data. If no ID is set a new one
    # is automatically generated.
    create: (model, data, callback) ->
        path = "data/"
        if data.id?
            path += "#{data.id}/"
            delete data.id
        data.docType = model

        @client.post path, data, (error, response, body) =>
            if error
                callback error
            else if response.statusCode is 409
                callback new Error("This document already exists")
            else if response.statusCode isnt 201
                callback new Error("Server error occured.")
            else
                callback null, body._id

    # Save all model attributes to DB.
    save: (model, data, callback) ->
        data.docType = model
        @client.put "data/#{data.id}/", data, (error, response, body) =>
            if error
                callback error
            else if response.statusCode is 404
                callback new Error("Document not found")
            else if response.statusCode isnt 200
                callback new Error("Server error occured.")
            else
                callback()

    # Save only given attributes to DB.
    updateAttributes: (model, id, data, callback) ->
        @client.put "data/merge/#{id}/", data, (error, response, body) =>
            if error
                callback error
            else if response.statusCode is 404
                callback new Error("Document not found")
            else if response.statusCode isnt 200
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
            else if response.statusCode isnt 200 and
            response.statusCode isnt 201
                callback new Error("Server error occured.")
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
        @client.del "data/#{id}/", (error, response, body) =>
            if error
                callback error
            else if response.statusCode is 404
                callback new Error("Document not found")
            else if response.statusCode isnt 204
                callback new Error("Server error occured.")
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
        @client.post "data/index/#{model.id}", data, (error, response, body) =>
            if error
                callback error
            else if response.statusCode isnt 200
                callback new Error(body)
            else
                callback null

    # Retrieve note through index. Give a query then grab results.
    # ex: Note.search "dragon", (err, docs) ->
    # ...
    #
    search: (model, query, callback) ->
        data =
            query: query

        @client.post "data/search/#{model.toLowerCase()}", data, \
                     (error, response, body) =>
            if error
                callback error
            else if response.statusCode isnt 200
                callback new Error(body)
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

    # Check if an error occurred. If any, it returns an a proper error.
    checkError: (error, response, body, code, callback) ->
        if error
            callback error
        else if response.statusCode isnt code
            callback new Error(body)
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
          if (doc.docType === "#{model}") {
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
                callback new Error(body)
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
                callback new Error(body)
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


    # Find an account with its ID. Returns it if it is found else it
    # returns null
    getAccount: (model, callback) ->
        @exists model, model.id, (err, res) =>
            if err
                callback err
            else if not res
                callback new Error("The linked model doesn't exist")
            else
                if not model.account?
                    callback new Error("The model doesn't have an account")
                else
                    @client.get "account/#{model.account}/", (err, res, body) =>
                        if err
                            callback err
                        else if res.statusCode is 404
                            callback new Error("The account desn't exist")
                        else if res.statusCode is 402
                            callback new Error("Data are corrupted")
                        else if body.docType isnt "Account"
                            callback new Error("The document isn't an account")
                        else
                            callback null, body


    # Create a new account from given data.
    createAccount: (model, data, callback) ->
        @exists model, model.id, (err, res) =>
            if err
                callback err
            else if not res
                callback new Error("The linked model doesn't exist")
            else
                if model.account?
                    callback new Error("The model has already an account")
                else
                    data =
                        login: data.login
                        password: data.password
                    @client.post 'account/', data, (err, res, body) =>
                        if err
                            callback err
                        else if res.statusCode is 401
                            callback new Error("The account doesn't have a field
                                'password'")
                        else if res.statusCode isnt 201
                            callback new Error("Server error occured.")
                        else
                            data = account: body._id
                            @updateAttributes model, model.id, data, (err) =>
                                if err
                                    callback err
                                else
                                    model.account = body._id
                                    data._id = body._id
                                    callback null, data


    # Update all account attributes to DB.
    updateAccount: (model, data, callback) ->
        @exists model, model.id, (err, res) =>
            if err
                callback err
            else if not res
                callback new Error("The linked model doesn't exist")
            else
                if not model.account?
                    callback new Error("The model doesn't have an account")
                else
                    data =
                        login: data.login
                        password: data.password
                    @client.put "account/#{model.account}/", data,
                    (err, res, body) =>
                        if err
                            callback err
                        else if res.statusCode is 404
                            callback new Error("Document not found")
                        else if res.statusCode is 401
                            callback new Error("The account doesn't have a field
                             'password'")
                        else if res.statusCode isnt 200
                            callback new Error("Server error occured.")
                        else
                            callback()


    # Update only given attributes to DB.
    mergeAccount: (model, data, callback) ->
        @exists model, model.id, (err, res) =>
            if err
                callback err
            else if not res
                callback new Error("The linked model doesn't exist")
            else
                if not model.account?
                    callback new Error("The model doesn't have an account")
                else
                    @client.put "account/merge/#{model.account}/", data,
                    (err, res, body) =>
                        if err
                            callback err
                        else if res.statusCode is 404
                            callback new Error("Document not found")
                        else if res.statusCode isnt 200
                            callback new Error("Server error occured.")
                        else
                            callback()


    # Destroy account in database.
    destroyAccount: (model, callback) ->
        @exists model, model.id, (err, res) =>
            if err
                callback err
            else if not res
                callback new Error("The linked model doesn't exist")
            else
                if not model.account?
                    callback new Error("The model doesn't have an account")
                else
                    @client.del "account/#{model.account}/", (err, res, body) =>
                        if err
                            callback err
                        else if res.statusCode is 404
                            callback new Error("Document not found")
                        else if res.statusCode isnt 204
                            callback new Error("Server error occured.")
                        else
                            data = account: null
                            @updateAttributes model, model.id, data, (err) =>
                                if err
                                    callback err
                                else
                                    model.account = null
                                    callback null

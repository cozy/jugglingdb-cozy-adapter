
exports.initialize = (schema, callback) ->
  schema.adapter = new exports.CozyDataSystem()
  process.nextTick(callback)


class exports.CozyDataSystem
    constructor: ->
        @_models = {}


    define: (descr) ->
        @._models[descr.model.modelName] = descr

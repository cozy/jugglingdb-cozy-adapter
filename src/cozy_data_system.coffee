
exports.initialize = (schema, callback) ->
  schema.adapter = new CozyDataSystem()
  process.nextTick(callback)


class CozyDataSystem
    constructor: ->
        @_models = {}


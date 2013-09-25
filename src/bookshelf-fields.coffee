CheckIt = require 'checkit'

deep_clone = (obj) ->
    res = {}
    for k, v of obj
        switch
            when v instanceof Array
                res[k] = v[..]
            when typeof v is 'object'
                res[k] = deep_clone v
            else
                res[k] = v
    res

plugin = (instance) ->
    model = instance.Model.prototype
    model.validate = (self, attrs, options) ->
        if not ('validate' of options) or options.validate
            json = @toJSON()
            checkit = CheckIt(json).run(deep_clone(@validations))
            if @model_validations? and @model_validations instanceof Array and @model_validations.length > 0
                model_validations = @model_validations
                checkit = checkit.then ->
                    CheckIt(all: json).applyToAll(model_validations[..]).run()
            checkit
    old_format = model.format
    model.format = (attrs, options) ->
        attrs = old_format.call this, attrs, options
        if @__meta? and @__meta.fields
            for f in @__meta.fields when 'format' of f
                f.format attrs, options
        attrs
    old_parse = model.parse
    model.parse = (resp, options) ->
        attrs = old_parse.call this, resp, options
        if @__meta? and @__meta.fields
            for f in @__meta.fields when 'parse' of f
                f.parse attrs, options
        attrs

enable_validation = (model) ->
    if model.prototype.initialize?
        old_init = model.prototype.initialize
        model.prototype.initialize = ->
            @on 'saving', @validate, this
            old_init.apply this, arguments
    else
        model.prototype.initialize = ->
            @on 'saving', @validate, this

field = (model, cls, name, options) ->
    f = new cls name, options
    f.contribute_to_model model

fields = (model, specs...) ->
    for [cls, name, options] in specs
        field model, cls, name, options

pollute_function_prototype = ->
    Function::field = (cls, name, options) -> field this, cls, name, options
    Function::fields = (specs...) -> specs.unshift this; fields.apply this, specs
    Function::enable_validation = -> enable_validation this

cleanup_function_prototype = ->
    delete Function::field
    delete Function::fields
    delete Function::enable_validation

exports =
    plugin: plugin
    field: field
    fields: fields
    enable_validation: enable_validation
    pollute_function_prototype: pollute_function_prototype
    cleanup_function_prototype: cleanup_function_prototype

for k, f of require('./fields')
    exports[k] = f

module.exports = exports
